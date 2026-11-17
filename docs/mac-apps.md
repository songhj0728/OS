# 맥 앱을 Windows 에서 돌리거나 테스트하기

**결론: Windows 에서 macOS GUI 앱을 직접 실행하는 실용적인 호환 레이어는 현재 없다.**
그래서 LiteWin 은 맥 앱 실행 기능을 넣지 않고, 가능한 방법만 정리한다.

| 방법 | 되는 것 | 판단 |
|---|---|---|
| Darling (리눅스용 macOS 호환 레이어, WSL2 위) | 일부 명령줄 도구 | GUI 앱은 거의 안 됨. 실험용 |
| 애플 하드웨어가 아닌 PC 에 macOS 가상머신 | — | macOS 라이선스(EULA)는 애플 하드웨어에서만 허용 → 제공하지 않음 |
| 클라우드 맥 (GitHub Actions macOS 러너, AWS EC2 Mac, MacinCloud 등) | 내가 만든 앱의 빌드·테스트, 원격 화면 | 합법적이고 현실적 |
| 크로스플랫폼 앱의 Windows 판 사용 | 대부분의 생산성 앱 | 가장 간단 |

## 개발자가 맥용 빌드를 테스트하려면
- GitHub 저장소에 `.github/workflows` 로 `runs-on: macos-latest` 작업을 만들면, 푸시할 때마다 실제 macOS 에서 빌드/테스트가 돈다 (공개 저장소 무료).
- 화면을 보며 써봐야 하면 시간 단위로 빌리는 클라우드 맥을 쓴다.
