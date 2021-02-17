build-mixin:
	pushd ../tns-mixin && jb install && popd
	mkdir -p dashboards
	mixtool generate dashboards -d ./dashboards ../tns-mixin/mixin.libsonnet
