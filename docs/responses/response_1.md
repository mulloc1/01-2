# 평가 문항 1 · OOM Crash

`MEMORY_LIMIT`만 `50MB`와 `512MB`로 바꿔 비교했습니다.

Before 로그에서는 2026-09-28 16:42:44에 힙이 25MB, 16:42:47에 50MB로 증가했습니다. 곧바로 `Memory limit exceeded (50MB >= 50MB)`와 `Self-terminating process 1921`이 기록되어 MemoryGuard가 프로세스를 종료한 것을 확인했습니다.

After 로그에서는 512MB 조건으로 약 47초 동안 실행되며 힙이 25MB부터 375MB까지 계속 증가했지만 MemoryGuard 종료 메시지는 발생하지 않았습니다. 따라서 한도를 높여 생존 시간은 늘었지만, 메모리가 계속 증가하므로 누수 자체가 해결된 것은 아닙니다.

- [Before 실제 로그](../../evidence/oom/before/app.log)
- [After 실제 로그](../../evidence/oom/after/app.log)
