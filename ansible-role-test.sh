#!/bin/bash
#
# Ansible role test shim.
#
# Usage: [OPTIONS] ./tests/test.sh
#   - distro: a supported Docker distro version (default = "centos7")
#   - playbook: a playbook in the tests directory (default = "test.yml")
#   - cleanup: whether to remove the Docker container (default = true)
#   - container_id: the --name to set for the container (default = timestamp)
#   - test_idempotence: whether to test playbook's idempotence (default = true)
#
# License: MIT

# Exit on any individual command failure.
set -e

function default_include {
  # Pretty colors.
  red='\033[0;31m'
  green='\033[0;32m'
  neutral='\033[0m'

  timestamp=$(date +%s)

  # Allow environment variables to override defaults.
  distro=${distro:-"centos7"}
  playbook=${playbook:-"test.yml"}
  cleanup=${cleanup:-"true"}
  container_id=${container_id:-$timestamp}
  test_idempotence=${test_idempotence:-"true"}

  ## Set up vars for Docker setup.
  # CentOS 7
  if [ $distro = 'centos7' ]; then
    init="/usr/lib/systemd/systemd"
    opts="--privileged --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro"
    container="shelleg/docker-$distro-ansible:latest"
  # CentOS 6
  elif [ $distro = 'centos6' ]; then
    init="/sbin/init"
    opts="--privileged"
    container="geerlingguy/docker-$distro-ansible:latest"
  # Ubuntu 16.04
  elif [ $distro = 'ubuntu1604' ]; then
    init="/lib/systemd/systemd"
    opts="--privileged --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro"
    container="shelleg/docker-$distro-ansible:latest"
  # Ubuntu 14.04
  elif [ $distro = 'ubuntu1404' ]; then
    init="/sbin/init"
    opts="--privileged"
    container="geerlingguy/docker-$distro-ansible:latest"
  # Ubuntu 12.04
  elif [ $distro = 'ubuntu1204' ]; then
    init="/sbin/init"
    opts="--privileged"
    container="geerlingguy/docker-$distro-ansible:latest"
  # Debian 8
  elif [ $distro = 'debian9' ]; then
    init="/lib/systemd/systemd"
    opts="--privileged --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro"
    container="geerlingguy/docker-$distro-ansible:latest"
  # Debian 8
  elif [ $distro = 'debian8' ]; then
    init="/lib/systemd/systemd"
    opts="--privileged --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro"
    container="geerlingguy/docker-$distro-ansible:latest"
  # Fedora 24
  elif [ $distro = 'fedora24' ]; then
    init="/usr/lib/systemd/systemd"
    opts="--privileged --volume=/sys/fs/cgroup:/sys/fs/cgroup:ro"
    container="geerlingguy/docker-$distro-ansible:latest"
  fi
}
function finish {
  # Remove the Docker container (if configured).
  if [ "$cleanup" = true ]; then
    printf "Removing Docker container...\n"
    docker rm -f $container_id
  else
    printf ${green}"${container_id} is at your disposal\n you can use it like so:
      for playing around:
    docker run --detach --volume=$PWD:/etc/ansible/roles/role_under_test:rw --name $container_id $opts $container $init
      for running the playbook:
    docker exec $container_id env TERM=xterm env ANSIBLE_FORCE_COLOR=1 ansible-playbook /etc/ansible/roles/role_under_test/tests/$playbook
      for syntax checking:
    docker exec --tty $container_id env TERM=xterm ansible-galaxy install -r /etc/ansible/roles/role_under_test/tests/requirements.yml
      for idempotency tests:
    docker exec $container_id ansible-playbook /etc/ansible/roles/role_under_test/tests/$playbook | tee -a $idempotence
    tail $idempotence \
      | grep -q 'changed=0.*failed=0' \
      && (printf ${green}'Idempotence test: pass'${neutral}"\n") \
      || (printf ${red}'Idempotence test: fail'${neutral}"\n" && exit 1)
    "
  fi
  printf "\n"
}
trap finish EXIT
function run {
  # Run the container using the supplied OS.
  printf ${green}"Starting Docker container: $container ..."${neutral}"\n"
  docker pull geerlingguy/docker-$distro-ansible:latest
  docker run --detach --volume="$PWD":/etc/ansible/roles/role_under_test:rw --name $container_id $opts $container $init

  printf "\n"
}
function getreqs {
  # Install requirements if `requirements.yml` is present.
  if [ -f "$PWD/tests/requirements.yml" ]; then
    printf ${green}"Requirements file detected; installing dependencies."${neutral}"\n"
    docker exec --tty $container_id env TERM=xterm ansible-galaxy install -r /etc/ansible/roles/role_under_test/tests/requirements.yml
  fi
  printf "\n"
}
function ansible_syntax_test {
  # Test Ansible syntax.
  printf ${green}"Checking Ansible playbook syntax."${neutral}
  docker exec --tty $container_id env TERM=xterm ansible-playbook /etc/ansible/roles/role_under_test/tests/$playbook --syntax-check

  printf "\n"
}
function ansible_run {
  # Run Ansible playbook.
  printf ${green}"Running command: docker exec $container_id env TERM=xterm ansible-playbook /etc/ansible/roles/role_under_test/tests/$playbook"${neutral}
  docker exec $container_id env TERM=xterm env ANSIBLE_FORCE_COLOR=1 ansible-playbook /etc/ansible/roles/role_under_test/tests/$playbook
}
function ansible_idempotence_test {

  if [ "$test_idempotence" = true ]; then
    # Run Ansible playbook again (idempotence test).
    printf ${green}"Running playbook again: idempotence test"${neutral}
    idempotence=$(mktemp)
    docker exec $container_id ansible-playbook /etc/ansible/roles/role_under_test/tests/$playbook | tee -a $idempotence
    tail $idempotence \
      | grep -q 'changed=0.*failed=0' \
      && (printf ${green}'Idempotence test: pass'${neutral}"\n") \
      || (printf ${red}'Idempotence test: fail'${neutral}"\n" && exit 1)
  fi
}

default_include
run
getreqs
ansible_syntax_test
ansible_run
ansible_idempotence_test
