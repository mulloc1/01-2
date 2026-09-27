# OOM Crash 증거

실행 환경: Ubuntu 26.04 LTS ARM64 / 일반 사용자 `agent-dev` / 포트 `15034`  
고정 조건: `CPU_MAX_OCCUPY=10`, `MULTI_THREAD_ENABLE=false`

## Before & After

| 평가 지표 | Before | After |
|---|---:|---:|
| `MEMORY_LIMIT` | 50MB | 512MB |
| 관찰 시간 | 7초 | 48초 |
| 결과 | 프로세스 자체 종료 | 관찰 종료까지 생존 |
| 앱 힙 마지막 값 | 50MB | 375MB |
| 관측 최고 RSS | 44,620KB | 406,548KB |
| MemoryGuard 종료 로그 | 있음 | 없음 |

## 핵심 증거

```text
# Before — PID 1699
2026-09-24 13:01:19 [MemoryWorker] Current Heap: 25MB
2026-09-24 13:01:22 [MemoryWorker] Current Heap: 50MB
2026-09-24 13:01:22 [MemoryGuard] Memory limit exceeded (50MB >= 50MB)
2026-09-24 13:01:22 [MemoryGuard] Self-terminating process 1699 to prevent system instability.

# PID별 RSS 표본
13:01:18 PID=1699 RSS=19,016KB
13:01:21 PID=1699 RSS=44,620KB

# After
13:07:38 [MemoryWorker] Current Heap: 375MB
13:07:40 PID=2455 RSS=406,548KB
```

## 판정

메모리 한계를 높이면 생존 시간은 늘지만 RSS가 계속 증가하므로 누수 자체는 해결되지 않았다. 환경 변수 변경은 임시 완화이며 근본 해결은 할당된 메모리의 참조와 해제 경로를 수정하는 것이다.

