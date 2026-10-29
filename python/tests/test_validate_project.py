"""Static checks for scripts/validate-project.py."""

from __future__ import annotations

import importlib.util
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = REPO_ROOT / "scripts" / "validate-project.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("validate_project", MODULE_PATH)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_scan_detects_order_and_trade_class(tmp_path: Path) -> None:
    module = _load_module()
    source = tmp_path / "Bad.mq5"
    source.write_text(
        "void OnStart()\n{\n   OrderSend(request, result);\n   CTrade trade;\n}\n",
        encoding="utf-8",
    )
    issues = module.scan_forbidden_api(source, tmp_path)
    assert any("OrderSend" in issue for issue in issues)
    assert any("CTrade" in issue for issue in issues)


def test_scan_detects_trade_include(tmp_path: Path) -> None:
    module = _load_module()
    source = tmp_path / "BadInclude.mqh"
    source.write_text('#include <Trade\\Trade.mqh>\n', encoding="utf-8")
    issues = module.scan_forbidden_api(source, tmp_path)
    assert any("forbidden include" in issue for issue in issues)


def test_scan_allows_market_data_api(tmp_path: Path) -> None:
    module = _load_module()
    source = tmp_path / "Rates.mq5"
    source.write_text(
        "MqlRates rates[];\nCopyRates(_Symbol, _Period, 0, 10, rates);\n"
        "double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);\n",
        encoding="utf-8",
    )
    assert module.scan_forbidden_api(source, tmp_path) == []


def _write_exec_source(tmp_path: Path, module, body: str) -> Path:
    relative = "mt5/Experts/PATrendRiderXAUv1DemoEA.mq5"
    assert relative in module.EXEC_SOURCES
    source = tmp_path / Path(relative)
    source.parent.mkdir(parents=True, exist_ok=True)
    source.write_text(body, encoding="utf-8")
    return source


def test_scan_allows_order_send_only_in_exec_sources(tmp_path: Path) -> None:
    module = _load_module()
    source = _write_exec_source(
        tmp_path, module, "// OrderSend in a comment is not code\n"
        "bool sent = OrderSend(request, result);\n"
    )
    assert module.scan_forbidden_api(source, tmp_path) == []


def test_scan_still_blocks_network_in_exec_sources(tmp_path: Path) -> None:
    module = _load_module()
    source = _write_exec_source(tmp_path, module, "int rc = WebRequest(\"GET\", url, 0, 1000, buf);\n")
    issues = module.scan_forbidden_api(source, tmp_path)
    assert any("WebRequest" in issue for issue in issues)


def test_placeholder_scan(tmp_path: Path) -> None:
    module = _load_module()
    source = tmp_path / "Draft.mq5"
    source.write_text("// TODO wire this up\nint x = 1;\n", encoding="utf-8")
    issues = module.scan_placeholders(source)
    assert len(issues) == 1
    assert "TODO" in issues[0]


def test_layout_reports_missing_files(tmp_path: Path) -> None:
    module = _load_module()
    issues = module.check_layout(tmp_path)
    assert "missing README.md" in issues
    assert "missing mt5/Scripts/SimCoreTests.mq5" in issues


def test_repository_passes_static_checks(capsys) -> None:
    module = _load_module()
    assert module.main([]) == 0
    output = capsys.readouterr().out
    assert "forbidden API scan" in output
    assert "SUMMARY: checks=" in output
    assert "fail=0" in output
