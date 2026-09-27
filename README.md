# Linux Troubleshooting Mission

OrbStack의 Ubuntu ARM64 VM에서 `agent-leak-app`의 OOM, CPU 과점유, Deadlock을 재현하고 실제 로그와 시스템 관측값으로 분석한 저장소입니다.

평가 증거는 [OOM](evidence/oom.md), [CPU](evidence/cpu.md), [Deadlock](evidence/deadlock.md) 세 파일로 정리했습니다.

## 결과

| 장애 | Before → After | 결과 | 보고서 |
|---|---|---|---|
| OOM | `MEMORY_LIMIT=50 → 512` | 7초 종료 → 48초 관찰 동안 생존 | [OOM 리포트](reports/01_oom.md) |
| CPU | `CPU_MAX_OCCUPY=100 → 10` | 40초 종료 → 48초 관찰 동안 생존 | [CPU 리포트](reports/02_cpu.md) |
| Deadlock | `MULTI_THREAD_ENABLE=true → false` | PID 생존·진행 정지 → 정상 진행 | [Deadlock 리포트](reports/03_deadlock.md) |

`evidence/`에는 장애별 Before/After 수치와 핵심 로그만 남겼습니다.

## 로컬 실행 환경

- macOS Apple Silicon + OrbStack
- Ubuntu 26.04 LTS ARM64
- Linux `7.0.14-orbstack-00380-ga7e0a2dc9535`
- 실행 바이너리: `agent-app-leak/agent-leak-app-arm64`
- 실행 사용자: `agent-dev` (비-root)
- 관제 사용자: `agent-admin`
- 포트: `0.0.0.0:15034`

## 재현 방법

VM 환경은 다음 명령으로 복구합니다.

```bash
sudo ./scripts/setup_lab.sh "$(pwd)"
```

각 실험은 다음 형식으로 실행합니다.

```bash
./scripts/run_experiment.sh CASE PHASE MEMORY_LIMIT CPU_MAX_OCCUPY MULTI_THREAD_ENABLE DURATION_SECONDS
```

실제 제출 증거에 사용한 조합은 다음과 같습니다.

```bash
./scripts/run_experiment.sh oom before 50 10 false 45
./scripts/run_experiment.sh oom after 512 10 false 45
./scripts/run_experiment.sh cpu before 512 100 false 45
./scripts/run_experiment.sh cpu after 512 10 false 45
./scripts/run_experiment.sh deadlock before 512 10 true 45
./scripts/run_experiment.sh deadlock after 512 10 false 45
```

통합 증거에는 `monitor.sh`의 시스템 지표와 PID별 RSS, 0.25초 간격 CPU 표본에서 평가에 필요한 값만 추려 기록했습니다.

## 보안 및 해석 원칙

- `secret.key`는 VM에만 만들며 저장소에 커밋하지 않습니다.
- 앱 내부의 `Current Load`와 OS가 관측한 `%CPU`는 측정 창과 정의가 달라 별도 값으로 기록합니다.
- 환경 변수 변경은 재현·회피를 위한 임시 조치이며 코드 수준의 근본 해결이 아닙니다.
