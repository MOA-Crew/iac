# MOA Observability

MOA API 관측성은 두 층으로 나눈다.

1. **API 접근성/상태 코드**: 중앙 모니터링 스택의 Prometheus + blackbox-exporter가 `GET/OPTIONS /api/ping`을 주기적으로 프로브한다.
2. **실제 트래픽양/공통예외 종류**: 각 app EC2의 promtail이 Docker 로그를 Loki로 전송하고, Grafana가 `MOA_API_ACCESS`, `MOA_API_EXCEPTION` 로그 라벨을 LogQL로 집계한다.

## 로그 포맷 계약

BE 애플리케이션은 아래 marker를 남겨야 한다.

```text
MOA_API_ACCESS method=GET path=/api/foo status=200 duration_ms=12
MOA_API_EXCEPTION code=COMMON400 status=400 exception=MethodArgumentNotValidException method=POST path=/api/foo message=...
```

Grafana 대시보드 `MOA API Traffic & Exception Types`는 다음을 보여준다.

- 분당 API 호출량
- HTTP status class별 호출량
- 공통예외 code별 발생량
- exception class별 발생량
- 최근 예외 로그

## 배포

- `playbooks/site.yml`: dev/prod app EC2에 promtail 배포
- `playbooks/monitoring.yml`: 중앙 모니터링 호스트에 Grafana/Prometheus/blackbox 배포

CI의 Ansible syntax check는 `bootstrap.yml`, `site.yml`, `monitoring.yml`을 모두 검증한다.
