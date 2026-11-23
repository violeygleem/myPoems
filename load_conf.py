from pathlib import Path


def load_conf(conf_path: str | Path) -> dict[str, str]:
    config: dict[str, str] = {}
    path = Path(conf_path)
    if not path.exists():
        raise FileNotFoundError(f"配置文件不存在: {path}")

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or line.startswith(";"):
            continue
        if line.startswith("[") and line.endswith("]"):
            continue
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        config[key.strip()] = value.strip()

    return config


def parse_csv(value: str | None) -> list[str]:
    if not value:
        return []
    return [item.strip() for item in value.split(",") if item.strip()]


def parse_mapping(value: str | None) -> dict[str, str]:
    result: dict[str, str] = {}
    for item in parse_csv(value):
        if ":" in item:
            src, dst = item.split(":", 1)
            result[src.strip()] = dst.strip()
    return result