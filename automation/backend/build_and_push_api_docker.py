#!/usr/bin/env python3
# dash Build and push FastAPI image to Docker Hub (prod only)
"""Build silvella/arcori_api and push to Docker Hub.

Requires wfrun/dashboard with WFRUN_MODE=prod (loads .env.prod).
Before build, sets LOGGING_SWITCH = False under the Python build context
(restored after). Records API_IMAGE_TAG in the prod env file.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from image_tag_env import (
    Colors,
    check_docker,
    confirm_build,
    disable_python_logging_switches,
    docker_platform,
    docker_username,
    ensure_deploy_keys_in_environ,
    record_image_tag,
    require_wfrun_prod,
    resolve_versioned_image_tag,
    restore_logging_switches,
)

IMAGE_NAME = "arcori_api"
TAG_KEY = "API_IMAGE_TAG"


def build_and_push(
    *,
    project_root: Path,
    image_tag: str,
) -> bool:
    username = docker_username()
    platform = docker_platform()
    full_image = f"{username}/{IMAGE_NAME}:{image_tag}"
    build_context = project_root / "app_codebase" / "python_base_05"
    dockerfile = build_context / "Dockerfile"

    print(f"\n{Colors.BLUE}Configuration:{Colors.NC}")
    print(f"  Docker Username: {username}")
    print(f"  Image Name: {IMAGE_NAME}")
    print(f"  Image Tag: {image_tag}")
    print(f"  Full Image: {full_image}")
    print(f"  Platform: {platform}")
    print(f"  Dockerfile: {dockerfile}")
    print(f"  Build Context: {build_context}")
    print()

    if not dockerfile.is_file():
        print(f"{Colors.RED}Error: Dockerfile not found at {dockerfile}{Colors.NC}")
        return False

    if not confirm_build():
        return False

    print(f"\n{Colors.BLUE}Building Docker image...{Colors.NC}")
    build_cmd = [
        "docker",
        "build",
        "--platform",
        platform,
        "-f",
        str(dockerfile),
        "-t",
        full_image,
        str(build_context),
    ]
    try:
        subprocess.run(build_cmd, check=True)
        print(f"{Colors.GREEN}✓ Docker image built successfully{Colors.NC}")
    except subprocess.CalledProcessError:
        print(f"{Colors.RED}✗ Docker build failed{Colors.NC}")
        return False

    if image_tag != "latest":
        latest_tag = f"{username}/{IMAGE_NAME}:latest"
        print(f"\n{Colors.BLUE}Tagging as latest...{Colors.NC}")
        subprocess.run(["docker", "tag", full_image, latest_tag], check=True)
        print(f"{Colors.GREEN}✓ Tagged as latest{Colors.NC}")

    print(f"\n{Colors.BLUE}Pushing to Docker Hub...{Colors.NC}")
    try:
        subprocess.run(["docker", "push", full_image], check=True)
        print(f"{Colors.GREEN}✓ Image pushed successfully{Colors.NC}")
    except subprocess.CalledProcessError:
        print(
            f"{Colors.RED}✗ Push failed. Make sure you're logged in: docker login{Colors.NC}"
        )
        return False

    if image_tag != "latest":
        latest_tag = f"{username}/{IMAGE_NAME}:latest"
        print(f"\n{Colors.BLUE}Pushing latest tag...{Colors.NC}")
        try:
            subprocess.run(["docker", "push", latest_tag], check=True)
            print(f"{Colors.GREEN}✓ Latest tag pushed successfully{Colors.NC}")
        except subprocess.CalledProcessError:
            pass

    return True


def main() -> None:
    print(f"{Colors.BLUE}=== FastAPI Docker Build and Push ==={Colors.NC}\n")

    project_root, env_path = require_wfrun_prod()
    ensure_deploy_keys_in_environ()
    image_tag = resolve_versioned_image_tag(project_root)
    build_context = project_root / "app_codebase" / "python_base_05"

    if not check_docker():
        print(
            f"{Colors.RED}Error: Docker is not running. "
            f"Start Docker and try again.{Colors.NC}"
        )
        sys.exit(1)

    try:
        disable_python_logging_switches(build_context)
        success = build_and_push(project_root=project_root, image_tag=image_tag)
        if not success:
            sys.exit(1)

        record_image_tag(env_path, TAG_KEY, image_tag)
        username = docker_username()
        print(f"\n{Colors.GREEN}=== Build and Push Complete ==={Colors.NC}")
        print(
            f"Image available at: {Colors.BLUE}"
            f"{username}/{IMAGE_NAME}:{image_tag}{Colors.NC}"
        )
        print("  Next: wfrun (prod) → automation/backend/build_and_push_dart_docker.py")
        print("  Then: wfrun (prod) → automation/production/deploy_vps.py")
        print()
    except KeyboardInterrupt:
        print(f"\n{Colors.YELLOW}Interrupted.{Colors.NC}")
        sys.exit(1)
    except Exception as e:
        print(f"\n{Colors.RED}Error: {e}{Colors.NC}")
        sys.exit(1)
    finally:
        restore_logging_switches(build_context)


if __name__ == "__main__":
    main()
