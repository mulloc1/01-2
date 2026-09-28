# 평가 문항 2 · CPU Latency

`MEMORY_LIMIT=512`, `MULTI_THREAD_ENABLE=false`로 고정하고 `CPU_MAX_OCCUPY`만 `100`과 `10`으로 바꿨습니다.

Before에서는 CpuWorker의 부하가 5.00%에서 55.15%까지 계속 상승했고, 2026-09-28 16:44:20에 `CPU Threshold Violated! (55.15%)`가 기록된 뒤 프로세스가 종료됐습니다.

After에서는 정상 모니터링 시나리오가 선택됐습니다. CpuWorker가 10%에 도달하면 `Starting cooldown`, 5%로 내려가면 `Resuming load increase`를 반복했고 약 47초의 관찰 시간 동안 임계 위반 없이 실행됐습니다. 로그 형태가 다른 이유는 설정 변경에 따라 에이전트가 장애 시나리오와 정상 시나리오를 다르게 선택하기 때문입니다.

- [Before 실제 로그](../../evidence/cpu/before/app.log)
- [After 실제 로그](../../evidence/cpu/after/app.log)
