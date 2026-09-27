# CPU Latency 증거

실행 환경: Ubuntu 26.04 LTS ARM64 / 일반 사용자 `agent-dev` / 포트 `15034`  
고정 조건: `MEMORY_LIMIT=512`, `MULTI_THREAD_ENABLE=false`

## Before & After

| 평가 지표 | Before | After |
|---|---:|---:|
| `CPU_MAX_OCCUPY` | 100% | 10% |
| 관찰 시간 | 40초 | 48초 |
| 결과 | 임계 위반 후 종료 | 관찰 종료까지 생존 |
| 앱 내부 최고 부하 | 55.14% | 10.00% |
| OS 0.25초 샘플 최고 CPU | 18.90% | 7.57% |
| 임계 위반 로그 | 있음 | 없음 |

## 핵심 증거

```text
# Before — PID 6131
2026-09-24 15:00:59 [CpuWorker] Current Load: 38.63%
2026-09-24 15:01:06 [CpuWorker] Current Load: 41.71%
2026-09-24 15:01:09 [CpuWorker] Current Load: 45.88%
2026-09-24 15:01:12 [CpuWorker] Current Load: 55.14%
2026-09-24 15:01:12 [CpuWorker] CPU Threshold Violated! (55.13999999999999%).

# /proc/PID/stat 0.25초 간격 표본
15:01:06 PID=6131 CPU=18.90%

# After
[CpuWorker] Current Load: 5.00%
[CpuWorker] Peak reached (10.00%). Starting cooldown...
[CpuWorker] Current Load: 10.00%
[CpuWorker] Cooldown complete (5.00%). Resuming load increase...
```

## 판정

CPU 제한을 10%로 낮추자 부하가 5~10% 범위에서 조절되고 보호 종료가 발생하지 않았다. 앱 내부 부하와 OS CPU는 측정 기준이 달라 별도 값으로 기록했다.

