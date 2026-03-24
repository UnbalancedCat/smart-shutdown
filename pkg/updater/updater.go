package updater

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	"golang.org/x/mod/semver"
)

type githubRelease struct {
	TagName string `json:"tag_name"`
	Assets  []struct {
		Name               string `json:"name"`
		BrowserDownloadURL string `json:"browser_download_url"`
	} `json:"assets"`
}

func CheckForUpdate(currentVersion string) (hasNew bool, latestVersion string, downloadURL string) {
	if currentVersion == "dev" || currentVersion == "" {
		return false, "", ""
	}

	client := http.Client{Timeout: 8 * time.Second}
	resp, err := client.Get("https://api.github.com/repos/UnbalancedCat/smart-shutdown/releases/latest")
	if err != nil || resp.StatusCode != 200 {
		return false, "", ""
	}
	defer resp.Body.Close()

	var release githubRelease
	if err := json.NewDecoder(resp.Body).Decode(&release); err != nil {
		return false, "", ""
	}

	latestVersion = release.TagName
	cv := currentVersion
	if !semver.IsValid(cv) && !strings.HasPrefix(cv, "v") {
		cv = "v" + cv
	}
	lv := latestVersion
	if !semver.IsValid(lv) && !strings.HasPrefix(lv, "v") {
		lv = "v" + lv
	}

	if semver.Compare(cv, lv) < 0 {
		expectedAsset := fmt.Sprintf("smart-shutdown_%s_%s", runtime.GOOS, runtime.GOARCH)
		if runtime.GOOS == "windows" {
			expectedAsset += ".exe"
		}

		for _, asset := range release.Assets {
			if asset.Name == expectedAsset {
				return true, latestVersion, asset.BrowserDownloadURL
			}
		}
	}

	return false, "", ""
}

func CheckAndPrintUpdate(currentVersion string) {
	fmt.Printf("当前内核版本: %s\n", currentVersion)
	fmt.Println("正在检测云端发布节点是否有可用新版本...")
	hasNew, latest, _ := CheckForUpdate(currentVersion)
	if hasNew {
		fmt.Printf("\n[发现更新] 获取到最新稳定版本: %s\n", latest)
		fmt.Println("请执行 'smart-shutdown update' 以全自动获取并覆盖部署该更新。")
	} else {
		fmt.Println("当前已是最新运行版本，暂无可用更新。")
	}
}

func DownloadAndReplace(downloadURL string) error {
	currentExe, err := os.Executable()
	if err != nil {
		return fmt.Errorf("无法溯源自身执行路径: %v", err)
	}

	tempExe := filepath.Join(os.TempDir(), "smart-shutdown-update.tmp")
	out, err := os.Create(tempExe)
	if err != nil {
		return fmt.Errorf("系统缓存区句柄开辟失败: %v", err)
	}

	resp, err := http.Get(downloadURL)
	if err != nil || resp.StatusCode != 200 {
		out.Close()
		os.Remove(tempExe)
		return fmt.Errorf("网络传输流建立失败，节点远端可能受限")
	}

	_, err = io.Copy(out, resp.Body)
	resp.Body.Close()
	out.Close()

	if err != nil {
		os.Remove(tempExe)
		return fmt.Errorf("物理覆盖字节流中断: %v", err)
	}

	if runtime.GOOS == "windows" {
		oldExe := currentExe + ".old"
		os.Remove(oldExe) 
		if err := os.Rename(currentExe, oldExe); err != nil {
			return fmt.Errorf("操作系统拒绝进程脱壳 (文件锁互斥): %v", err)
		}
	}

	if err := copyFile(tempExe, currentExe); err != nil {
		if runtime.GOOS == "windows" {
			os.Rename(currentExe+".old", currentExe)
		}
		return fmt.Errorf("原子级覆盖执行核心挫败: %v", err)
	}
	os.Remove(tempExe)

	if runtime.GOOS != "windows" {
		os.Chmod(currentExe, 0755)
	}

	return nil
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, in)
	return err
}
