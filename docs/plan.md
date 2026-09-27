# Linux 트러블슈팅 실습 실행 기록

## 목표

OrbStack Ubuntu ARM64에서 `agent-leak-app`의 OOM, CPU 보호 종료, Deadlock을 한 변수씩 변경해 재현하고 GitHub Issue 형식 보고서와 원본 증거를 제출한다.

## 환경

- Ubuntu 26.04 LTS ARM64, Linux `7.0.14-orbstack-00380-ga7e0a2dc9535`
- 바이너리: `agent-app-leak/agent-leak-app-arm64`
- 실행 계정: `agent-dev`; 관제 계정: `agent-admin`
- 배포 경로: `/opt/agent-app`; 설정: `/etc/agent-app/agent-app.env`
- 실제 바이너리의 부팅 검사는 문서 예시보다 하나 많은 6단계이며 모두 통과했다.

## 실행 조합

| 장애 | Before | After | 고정 조건 |
|---|---|---|---|
| OOM | `MEMORY_LIMIT=50` | `512` | CPU 10, multi-thread false |
| CPU | `CPU_MAX_OCCUPY=100` | `10` | Memory 512, multi-thread false |
| Deadlock | `MULTI_THREAD_ENABLE=true` | `false` | Memory 512, CPU 10 |

실제 바이너리는 CPU 100 설정에서 부하를 계속 올리다가 보호 종료하고, CPU 10에서는 5~10% 범위를 순환했다. 따라서 문서 초안과 달리 100을 CPU 장애 Before, 10을 After로 사용했다.

## 수집 방법

- `scripts/setup_lab.sh`: 계정·공유 경로·키·환경·관제 스크립트 배포
- `scripts/run_experiment.sh`: 단일 실행 잠금, 앱 실행, PID/포트/로그/자원/스레드 상태 수집
- `scripts/monitor.sh`: 정확한 프로세스 이름으로 최신 워커 PID를 기록
- `scripts/sample_process_cpu.sh`: `/proc/PID/stat`을 0.25초 간격으로 측정
- 평가용 결과: `evidence/oom.md`, `evidence/cpu.md`, `evidence/deadlock.md`
- 최종 보고서: `reports/01_oom.md`, `02_cpu.md`, `03_deadlock.md`

## 완료 결과

- OOM: 50MB에서는 7초 종료, 512MB에서는 48초 관찰 동안 생존
- CPU: 100에서는 40초 종료, 10에서는 48초 관찰 동안 생존
- Deadlock: true에서 PID·포트 생존 상태로 `futex_wait`, false에서 정상 진행
- 모든 보고서 수치와 로그는 저장된 원본 증거에 연결됨
- 비밀키는 VM에만 존재하며 저장소에 포함하지 않음
