#!/usr/bin/env python3
"""Compile a platform Vault bootstrap model into Kubernetes manifests.

The parser intentionally supports the small YAML subset used by this repository's
fixtures so the smoke test can run without PyYAML or network access.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Any


class ModelError(ValueError):
    pass


def parse_scalar(value: str) -> Any:
    value = value.strip()
    if value in {"", "null", "Null", "NULL", "~"}:
        return None
    if value in {"true", "True", "TRUE"}:
        return True
    if value in {"false", "False", "FALSE"}:
        return False
    if value == "{}":
        return {}
    if value == "[]":
        return []
    if (value.startswith('"') and value.endswith('"')) or (
        value.startswith("'") and value.endswith("'")
    ):
        return value[1:-1]
    if re.fullmatch(r"-?[0-9]+", value):
        return int(value)
    return value


def strip_comment(line: str) -> str:
    in_single = False
    in_double = False
    for index, char in enumerate(line):
        if char == "'" and not in_double:
            in_single = not in_single
        elif char == '"' and not in_single:
            in_double = not in_double
        elif char == "#" and not in_single and not in_double:
            if index == 0 or line[index - 1].isspace():
                return line[:index].rstrip()
    return line.rstrip()


def load_yaml_subset(path: Path) -> Any:
    rows: list[tuple[int, str]] = []
    for number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if "\t" in raw_line[: len(raw_line) - len(raw_line.lstrip())]:
            raise ModelError(f"{path}:{number}: tabs are not supported for indentation")
        line = strip_comment(raw_line)
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip(" "))
        rows.append((indent, line.strip()))

    def split_key_value(text: str) -> tuple[str, str]:
        if ":" not in text:
            raise ModelError(f"{path}: expected key/value entry, got {text!r}")
        key, value = text.split(":", 1)
        key = key.strip()
        if not key:
            raise ModelError(f"{path}: empty mapping key")
        return key, value.strip()

    def parse_block(index: int, indent: int) -> tuple[Any, int]:
        if index >= len(rows):
            return {}, index
        actual_indent, text = rows[index]
        if actual_indent < indent:
            return {}, index
        if actual_indent != indent:
            raise ModelError(f"{path}: unexpected indent before {text!r}")

        if text.startswith("- "):
            items: list[Any] = []
            while index < len(rows):
                actual_indent, text = rows[index]
                if actual_indent != indent or not text.startswith("- "):
                    break
                item_text = text[2:].strip()
                index += 1
                if not item_text:
                    value, index = parse_block(index, indent + 2)
                    items.append(value)
                    continue
                if ":" in item_text:
                    key, scalar = split_key_value(item_text)
                    item: dict[str, Any] = {}
                    if scalar:
                        item[key] = parse_scalar(scalar)
                    elif index < len(rows) and rows[index][0] > indent:
                        item[key], index = parse_block(index, rows[index][0])
                    else:
                        item[key] = None
                    if index < len(rows) and rows[index][0] > indent:
                        extra, index = parse_block(index, rows[index][0])
                        if not isinstance(extra, dict):
                            raise ModelError(f"{path}: list item continuation must be a mapping")
                        item.update(extra)
                    items.append(item)
                else:
                    items.append(parse_scalar(item_text))
            return items, index

        mapping: dict[str, Any] = {}
        while index < len(rows):
            actual_indent, text = rows[index]
            if actual_indent != indent or text.startswith("- "):
                break
            key, scalar = split_key_value(text)
            index += 1
            if scalar:
                mapping[key] = parse_scalar(scalar)
            elif index < len(rows) and rows[index][0] > indent:
                mapping[key], index = parse_block(index, rows[index][0])
            else:
                mapping[key] = None
        return mapping, index

    if not rows:
        return {}
    result, final_index = parse_block(0, rows[0][0])
    if final_index != len(rows):
        raise ModelError(f"{path}: could not parse all input")
    return result


def q(value: Any) -> str:
    text = "" if value is None else str(value)
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def block(lines: list[str], indent: int = 4) -> str:
    prefix = " " * indent
    if not lines:
        return prefix + "true\n"
    return "".join(f"{prefix}{line}\n" for line in lines)


def names(values: list[dict[str, Any]], key: str = "name") -> list[str]:
    return [str(value[key]) for value in values if key in value]


def require_list(model: dict[str, Any], key: str) -> list[Any]:
    value = model.get(key, [])
    if value is None:
        return []
    if not isinstance(value, list):
        raise ModelError(f"{key} must be a list")
    return value


def shell_quote(value: Any) -> str:
    text = "" if value is None else str(value)
    return "'" + text.replace("'", "'\"'\"'") + "'"


def render_policy_hcl(model: dict[str, Any]) -> dict[str, list[str]]:
    rendered: dict[str, list[str]] = {}
    for policy in require_list(model, "policies"):
        policy_name = str(policy["name"])
        lines: list[str] = []
        for rule in policy.get("rules", []):
            capabilities = rule.get("capabilities", ["read"])
            rendered_caps = ", ".join(q(capability) for capability in capabilities)
            lines.extend(
                [
                    f'path "{rule["path"]}" {{',
                    f"  capabilities = [{rendered_caps}]",
                    "}",
                    "",
                ]
            )
        rendered[policy_name] = lines

    for secret in require_list(model, "vsoSecrets"):
        policy_name = str(secret.get("policy", "vso-read"))
        mount = str(secret["mount"])
        path = str(secret["path"]).strip("/")
        rendered.setdefault(policy_name, [])
        rendered[policy_name].extend(
            [
                f'path "{mount}/data/{path}" {{',
                '  capabilities = ["read"]',
                "}",
                "",
            ]
        )
    return rendered


def render_bootstrap_script(model: dict[str, Any]) -> list[str]:
    lines = [
        "#!/usr/bin/env sh",
        "set -eu",
        "",
        ': "${VAULT_ADDR:?VAULT_ADDR is required}"',
        ': "${VAULT_TOKEN:?VAULT_TOKEN is required}"',
        "",
    ]

    for mount in require_list(model, "authMounts"):
        mount_type = mount.get("type", "kubernetes")
        lines.append(
            f"vault auth enable -path={shell_quote(mount['name'])} {shell_quote(mount_type)} || true"
        )

    for mount in require_list(model, "kvMounts"):
        version = mount.get("version", 2)
        lines.append(
            f"vault secrets enable -path={shell_quote(mount['name'])} -version={shell_quote(version)} kv || true"
        )

    policies = render_policy_hcl(model)
    for policy_name in sorted(policies):
        lines.extend(
            [
                f"cat > /tmp/{policy_name}.hcl <<'POLICY'",
                *policies[policy_name],
                "POLICY",
                f"vault policy write {shell_quote(policy_name)} /tmp/{policy_name}.hcl",
                "",
            ]
        )

    for role in require_list(model, "kubernetesRoles"):
        service_accounts = role.get("serviceAccounts", [])
        account_names = ",".join(names(service_accounts))
        namespaces = ",".join(names(service_accounts, "namespace"))
        policies_csv = ",".join(role.get("policies", []))
        audiences = ",".join(role.get("audiences", []))
        command = [
            "vault",
            "write",
            f"auth/{role['mount']}/role/{role['name']}",
            f"bound_service_account_names={account_names}",
            f"bound_service_account_namespaces={namespaces}",
            f"policies={policies_csv}",
            f"ttl={role.get('ttl', '1h')}",
        ]
        if audiences:
            command.append(f"audience={audiences}")
        lines.append(" ".join(shell_quote(part) for part in command))

    if require_list(model, "transitKeys"):
        lines.append("vault secrets enable -path='transit' transit || true")
    for key in require_list(model, "transitKeys"):
        lines.append(
            f"vault write -f {shell_quote('transit/keys/' + str(key['name']))} type={shell_quote(key.get('type', 'rsa-2048'))}"
        )

    for database in require_list(model, "databaseDynamicCredentials"):
        if not database.get("enabled", True):
            continue
        mount = database.get("mount", "database")
        lines.append(f"vault secrets enable -path={shell_quote(mount)} database || true")
        allowed_roles = ",".join(names(database.get("roles", [])))
        lines.append(
            " ".join(
                shell_quote(part)
                for part in [
                    "vault",
                    "write",
                    f"{mount}/config/{database['name']}",
                    f"plugin_name={database['plugin']}",
                    f"allowed_roles={allowed_roles}",
                    f"connection_url={database['connectionUrl']}",
                    f"username={database['adminUsername']}",
                    f"password={database['adminPassword']}",
                ]
            )
        )
        for role in database.get("roles", []):
            lines.append(
                " ".join(
                    shell_quote(part)
                    for part in [
                        "vault",
                        "write",
                        f"{mount}/roles/{role['name']}",
                        f"db_name={database['name']}",
                        f"creation_statements={role['creationStatements']}",
                        f"default_ttl={role.get('defaultTtl', '1h')}",
                        f"max_ttl={role.get('maxTtl', '24h')}",
                    ]
                )
            )

    for rabbitmq in require_list(model, "rabbitmqDynamicCredentials"):
        if not rabbitmq.get("enabled", True):
            continue
        mount = rabbitmq.get("mount", "rabbitmq")
        lines.append(f"vault secrets enable -path={shell_quote(mount)} rabbitmq || true")
        lines.append(
            " ".join(
                shell_quote(part)
                for part in [
                    "vault",
                    "write",
                    f"{mount}/config/connection",
                    f"connection_uri={rabbitmq['connectionUri']}",
                    f"username={rabbitmq['adminUsername']}",
                    f"password={rabbitmq['adminPassword']}",
                ]
            )
        )
        for role in rabbitmq.get("roles", []):
            lines.append(
                " ".join(
                    shell_quote(part)
                    for part in [
                        "vault",
                        "write",
                        f"{mount}/roles/{role['name']}",
                        f"vhosts={role.get('vhosts', '*')}",
                        f"tags={role.get('tags', '')}",
                        f"configure={role.get('configure', '.*')}",
                        f"write={role.get('write', '.*')}",
                        f"read={role.get('read', '.*')}",
                    ]
                )
            )

    return lines


def metadata(model: dict[str, Any]) -> dict[str, str]:
    value = model.get("metadata", {})
    if not isinstance(value, dict):
        raise ModelError("metadata must be a mapping")
    return {
        "name": str(value.get("name", "${VAULT_BOOTSTRAP_NAME}")),
        "namespace": str(value.get("namespace", "${VAULT_BOOTSTRAP_NAMESPACE}")),
        "vaultAddress": str(value.get("vaultAddress", "${VAULT_ADDR}")),
        "tokenSecretName": str(value.get("tokenSecretName", "${VAULT_BOOTSTRAP_TOKEN_SECRET_NAME}")),
        "tokenSecretKey": str(value.get("tokenSecretKey", "${VAULT_BOOTSTRAP_TOKEN_SECRET_KEY}")),
        "serviceAccountName": str(value.get("serviceAccountName", "${VAULT_BOOTSTRAP_SERVICE_ACCOUNT_NAME}")),
    }


def render_config_map(model: dict[str, Any]) -> str:
    meta = metadata(model)
    script = render_bootstrap_script(model)
    return f"""apiVersion: v1
kind: ConfigMap
metadata:
  name: {q(meta["name"] + "-script")}
  namespace: {q(meta["namespace"])}
data:
  bootstrap.sh: |
{block(script, 4).rstrip()}
"""


def render_job(model: dict[str, Any]) -> str:
    meta = metadata(model)
    name = meta["name"]
    return f"""apiVersion: batch/v1
kind: Job
metadata:
  name: {q(name)}
  namespace: {q(meta["namespace"])}
spec:
  template:
    spec:
      restartPolicy: OnFailure
      serviceAccountName: {q(meta["serviceAccountName"])}
      containers:
        - name: vault-bootstrap
          image: "${{VAULT_BOOTSTRAP_IMAGE}}"
          imagePullPolicy: IfNotPresent
          command:
            - /bin/sh
            - /bootstrap/bootstrap.sh
          env:
            - name: VAULT_ADDR
              value: {q(meta["vaultAddress"])}
            - name: VAULT_TOKEN
              valueFrom:
                secretKeyRef:
                  name: {q(meta["tokenSecretName"])}
                  key: {q(meta["tokenSecretKey"])}
          volumeMounts:
            - name: bootstrap
              mountPath: /bootstrap
      volumes:
        - name: bootstrap
          configMap:
            name: {q(name + "-script")}
            defaultMode: 0755
"""


def render_vault_auth(role: dict[str, Any], namespace: str) -> str:
    service_accounts = role.get("serviceAccounts", [])
    service_account_name = service_accounts[0]["name"] if service_accounts else "${VSO_SERVICE_ACCOUNT_NAME}"
    service_account_namespace = (
        service_accounts[0].get("namespace", namespace) if service_accounts else namespace
    )
    return f"""apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  name: {q(role.get("vaultAuthName", str(role["name"]) + "-auth"))}
  namespace: {q(service_account_namespace)}
spec:
  method: kubernetes
  mount: {q(role["mount"])}
  kubernetes:
    role: {q(role["name"])}
    serviceAccount: {q(service_account_name)}
"""


def render_static_secret(secret: dict[str, Any]) -> str:
    namespace = str(secret["namespace"])
    return f"""apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: {q(secret["name"])}
  namespace: {q(namespace)}
spec:
  type: kv-v2
  mount: {q(secret["mount"])}
  path: {q(secret["path"])}
  destination:
    name: {q(secret["destinationSecretName"])}
    create: true
  refreshAfter: {q(secret.get("refreshAfter", "1h"))}
  vaultAuthRef: {q(secret.get("vaultAuthRef", "vso-auth"))}
"""


def render_dynamic_secret(item: dict[str, Any], kind: str) -> str:
    if not item.get("enabled", True) or "destinationSecretName" not in item:
        return ""
    namespace = str(item.get("namespace", "${VAULT_DYNAMIC_SECRET_NAMESPACE}"))
    mount = str(item.get("mount", "database" if kind == "database" else "rabbitmq"))
    path_prefix = "creds"
    return f"""apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultDynamicSecret
metadata:
  name: {q(item["name"] + "-dynamic")}
  namespace: {q(namespace)}
spec:
  mount: {q(mount)}
  path: {q(path_prefix + "/" + str(item["name"]))}
  destination:
    name: {q(item["destinationSecretName"])}
    create: true
  renewalPercent: {item.get("renewalPercent", 67)}
  vaultAuthRef: {q(item.get("vaultAuthRef", "vso-auth"))}
"""


def render_documents(model: dict[str, Any]) -> list[str]:
    meta = metadata(model)
    docs = [render_config_map(model), render_job(model)]
    docs.extend(render_vault_auth(role, meta["namespace"]) for role in require_list(model, "kubernetesRoles"))
    docs.extend(render_static_secret(secret) for secret in require_list(model, "vsoSecrets"))
    docs.extend(
        doc
        for doc in (
            render_dynamic_secret(item, "database")
            for item in require_list(model, "databaseDynamicCredentials")
        )
        if doc
    )
    docs.extend(
        doc
        for doc in (
            render_dynamic_secret(item, "rabbitmq")
            for item in require_list(model, "rabbitmqDynamicCredentials")
        )
        if doc
    )
    return docs


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="Vault policy model YAML")
    parser.add_argument("--output", type=Path, help="Write multi-document YAML to this path")
    args = parser.parse_args()

    try:
        model = load_yaml_subset(args.input)
        if not isinstance(model, dict):
            raise ModelError("model root must be a mapping")
        output = "---\n" + "---\n".join(render_documents(model))
    except Exception as exc:
        print(f"compile-vault-bootstrap-policy: {exc}", file=sys.stderr)
        return 1

    if args.output:
        args.output.write_text(output, encoding="utf-8")
    else:
        print(output, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
