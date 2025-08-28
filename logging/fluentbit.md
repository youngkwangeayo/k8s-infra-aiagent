
# basci k8s 베포
```bash
kubectl apply -f logging/fluentbit/fb-manifest.yaml

```




# 헬름으로 베포

## 베포영역
```bash

# 헬름차트 fluent-bit 패키지 로컬에 추가
helm repo add fluent https://fluent.github.io/helm-charts

# value 파일 맵핑 후 실제 k8s에 적용될 yaml 파일생성
helm template fb fluent/fluent-bit \
  --version 0.52.0 \
  -n logging \
  -f logging/fluentbit/dev-values.yaml \
  > logging/fluentbit/fb-manifest.yaml


# 헬름으로 k8s 베포
helm upgrade --install fb fluent/fluent-bit \
  --version 0.52.0 \
  -n logging \
  -f logging/fluentbit/dev-values.yaml 

```


## 로컬 추가 영역 (이미 만들어놨으니 하지마시오.)
```bash
# 헬름차트 fluent-bit 패키지 로컬에 추가
helm repo add fluent https://fluent.github.io/helm-charts

helm show chart fluent/fluent-bit --version 0.52.0  > logging/fluentbit/fb-chart.yaml 

helm show values fluent/fluent-bit > values.yaml  > logging/fluentbit/fb-value.yaml 
```

