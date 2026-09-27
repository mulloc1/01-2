# 기준 1 · OOM Crash

`MEMORY_LIMIT=50`에서 힙이 25MB→50MB로 증가한 뒤 PID 1699가 7초 만에 자체 종료됐다. 앱 로그에는 `Memory limit exceeded`와 `Self-terminating process 1699`가 연속 기록됐다.

512MB 실행은 48초 동안 생존했고 힙은 375MB, RSS는 406,548KB까지 증가했다. 생존 시간은 늘었지만 누수는 계속됐다. 상세 증거는 [OOM 보고서](../../reports/01_oom.md)에 있다.

