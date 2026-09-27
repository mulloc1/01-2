# [Bug] CPU Latency - 높은 CPU 설정에서 보호 정책이 프로세스를 종료

## 1. Description (현상 설명)

`MEMORY_LIMIT=512`, `MULTI_THREAD_ENABLE=false`로 고정하고 `CPU_MAX_OCCUPY`만 비교했다. 100% 설정에서는 앱 내부 부하가 계속 증가해 55.14%에서 임계 위반으로 종료됐다. 10% 설정에서는 부하가 5~10% 사이에서 상승과 cooldown을 반복하며 관찰 시간 동안 생존했다.

## 2. Evidence & Logs (증거 자료)

Before/After 조건과 핵심 로그는 [CPU 증거](../evidence/cpu.md)에 있다.

```text
2026-09-24 15:00:59,906 [INFO] [CpuWorker] Current Load: 38.63%
2026-09-24 15:01:06,159 [INFO] [CpuWorker] Current Load: 41.71%
2026-09-24 15:01:09,290 [INFO] [CpuWorker] Current Load: 45.88%
2026-09-24 15:01:12,411 [INFO] [CpuWorker] Current Load: 55.14%
2026-09-24 15:01:12,517 [CRITICAL] [CpuWorker] CPU Threshold Violated! (55.13999999999999%).
```

`/proc/6131/stat`의 CPU tick 차이를 0.25초 간격으로 측정한 결과 OS 관점 최고 프로세스 CPU는 18.90%였다. 앱 내부 `Current Load`는 앱의 시나리오 지표이고 OS 값은 실제 스케줄링 시간을 구간 측정한 값이므로 동일 수치로 간주하지 않는다. 다중 코어 VM의 시스템 전체 CPU는 0~1%로 보여 단일 프로세스 관측과 시스템 집계의 차이도 확인된다.

After 로그는 다음처럼 제한과 cooldown이 반복됨을 보여준다.

```text
[CpuWorker] Current Load: 5.00%
[CpuWorker] Peak reached (10.00%). Starting cooldown...
[CpuWorker] Current Load: 10.00%
[CpuWorker] Cooldown complete (5.00%). Resuming load increase...
```

## 3. Root Cause Analysis (원인 분석)

100% 설정은 워커가 부하를 계속 올리도록 허용하지만 앱의 안전 정책은 약 50%를 넘는 부하를 시스템 불안정 위험으로 판단해 프로세스를 종료한다. 종료 직전의 `CPU Threshold Violated`와 곧바른 PID 소실이 정책 종료의 직접 증거다. 앱은 실제 신호 이름을 출력하지 않으므로 SIGTERM이라고 단정하지 않는다.

프로세스 하나의 지속적인 CPU 소비는 같은 코어의 작업과 관리 프로세스의 응답 시간을 늘릴 수 있다. 근본 해결은 busy loop를 이벤트 대기·sleep/backoff 방식으로 바꾸고, 작업량을 제한된 worker pool에 배치하며, 운영 환경에서는 cgroup CPU quota를 함께 적용하는 것이다.

## 4. Workaround & Verification (조치 및 검증)

| 지표 | Before | After |
|---|---:|---:|
| `CPU_MAX_OCCUPY` | 100% | 10% |
| 나머지 조건 | 512MB, single-thread | 512MB, single-thread |
| 관찰 결과 | 40초 후 종료 | 48초 관찰 동안 생존 |
| 앱 내부 최고 부하 | 55.14% | 10.00% |
| OS 0.25초 샘플 최고 CPU | 18.90% | 7.57% |
| 임계 위반 로그 | 있음 | 없음 |

10%로 낮추는 것은 부하를 제한해 보호 종료를 피하는 운영상 완화책이다.
