# 평가 문항 4 · 리포트 형식과 증거

세 리포트는 모두 `Description → Evidence & Logs → Root Cause Analysis → Workaround & Verification` 순서로 작성했습니다. 즉 현상, 실제 로그, 원인, 환경변수 변경과 Before/After 결과가 한 흐름으로 이어집니다.

평가 시에는 각 장애의 Before/After `app.log`에서 환경값, 타임스탬프와 핵심 메시지를 직접 확인할 수 있습니다.

- OOM: PID 1921, `Memory limit exceeded`, `Self-terminating`
- CPU: 5.00%에서 55.15%까지 상승, `CPU Threshold Violated`
- Deadlock: 각 스레드의 자원 획득과 상대 자원 `WAITING`, 이후 로그 정지

PID 생존이나 스레드 상태를 추가로 확인해야 할 때는 실행 중 `pgrep`, `ps`, `ps -L`을 사용합니다.
