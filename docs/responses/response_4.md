# 기준 4 · 리포트 형식과 증거

세 보고서는 `Description → Evidence & Logs → Root Cause Analysis → Workaround & Verification` 순서를 사용한다. 각 수치는 원본 metadata, 앱 로그, 관제 로그, 프로세스·스레드 샘플에 연결했다.

- OOM: PID 1699, 13:01:22, MemoryGuard 종료
- CPU: PID 6131, 15:01:12, CPU threshold 위반
- Deadlock: PID 9660, 15:08:32 이후 로그 정지와 `futex_wait`

