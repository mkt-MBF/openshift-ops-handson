# OpenShiftのインストール

https://docs.openshift.com/container-platform/3.9/install_config/install/advanced_install.html

## インストール環境の構築

以下の手順で、OpenShiftをインストールするためのインフラ(VM、ネットワークなど)を構築します。

```bash
cd infrastructures/

export TF_VAR_platform_name= # 一意なプラットフォーム名を設定する
terraform init
terraform apply
```

これにより、空の(OpenShiftが入っていない)インフラが以下の構成で作成されます。

![Initial Infrastructure](/docs/images/initial_infrastructure.png)

## OpenShiftインストールのためのツールをインストール

1. bastionにログインする
    ```bash
    # ssh鍵の出力
    terraform output platform_private_key > .platform_private_key
    chmod 600 .platform_private_key
    # sshでログイン
    ssh `terraform output bastion_ssh` -i ./.platform_private_key
    ```
    
2. OpenShiftインストールに必要なツールをインストールする
    ```bash
    # サブスクリプションの登録
    sudo su -
    # RHNのユーザー名とパスワードを入力
    subscription-manager register
    # 所持しているOpenShiftサブスクリプションの検索
    subscription-manager list --available --matches "*OpenShift*"
    # 上記結果からOpenShiftサブスクリプションのPool IDを取得して入力
    subscription-manager attach --pool=XXXXXXXXXXX
    # 必要なリポジトリだけを有効化する
    subscription-manager repos --disable="*"
    subscription-manager repos --enable="rhel-7-server-rpms" \
     --enable="rhel-7-server-ose-3.9-rpms" \
     --enable="rhel-7-fast-datapath-rpms" \
     --enable="rhel-7-server-ansible-2.4-rpms"

    # 必要なツールをインストールする
    yum -y install atomic-openshift-utils atomic-openshift-clients
    
    # rootからログアウト
    exit

    # 動作確認
    ansible-playbook --version
    ls /usr/share/ansible/openshift-ansible
    # => inventory  playbooks  roles
    oc version
    ```

## OpenShiftインストール用にInventory Fileを作成する

以下ファイルを、 `~/inventory.yml` に作成する

**# --REPLACE--とあるところは環境に合わせて変更してください**

```yaml
OSEv3:
  children:
    masters:
      hosts:
        master.ocp.internal: ""
    etcd:
      hosts:
        master.ocp.internal: ""
    nodes:
      hosts:
        master.ocp.internal:
          openshift_node_labels:
            region: infra
        compute0.ocp.internal:
          openshift_node_labels:
            region: primary
  vars:
    ansible_user: cloud-user
    ansible_become: true
    oreg_url: "registry.access.redhat.com/openshift3/ose-${component}:${version}"
    openshift_deployment_type: openshift-enterprise
    openshift_release: "v3.9.27"
    containerized: true
    openshift_master_identity_providers:
      - name: 'test_identity_provider'
        login: true
        challenge: true
        kind: 'AllowAllPasswordIdentityProvider'
    os_sdn_network_plugin_name: 'redhat/openshift-ovs-networkpolicy'
    openshift_node_kubelet_args:
      kube-reserved: ['cpu=100m,memory=100Mi']
      system-reserved: ['cpu=100m,memory=100Mi']
      eviction-hard:
        - 'memory.available<4%'
        - 'nodefs.available<4%'
        - 'nodefs.inodesFree<4%'
        - 'imagefs.available<4%'
        - 'imagefs.inodesFree<4%'
      eviction-soft:
        - 'memory.available<8%'
        - 'nodefs.available<8%'
        - 'nodefs.inodesFree<8%'
        - 'imagefs.available<8%'
        - 'imagefs.inodesFree<8%'
      eviction-soft-grace-period:
        - 'memory.available=1m30s'
        - 'nodefs.available=1m30s'
        - 'nodefs.inodesFree=1m30s'
        - 'imagefs.available=1m30s'
        - 'imagefs.inodesFree=1m30s'
    openshift_disable_check: 'disk_availability,memory_availability'
    openshift_master_cluster_hostname: master.ocp.internal
    openshift_master_cluster_public_hostname: master.ocp.example.com
    openshift_master_default_subdomain: app.ocp.example.com
    openshift_cloudprovider_kind: aws
    openshift_clusterid: # --REPLACE-- TF_VAR_platform_nameと同一の値を設定する
```

## OpenShiftインストール用に全てのノードでSubscriptionを登録する

```bash
export ANSIBLE_HOST_KEY_CHECKING=False
export ANSIBLE_FORKS=20

ansible all -i ./inventory.yml -a "subscription-manager register --username=xxx --password=xxx"
ansible all -i ./inventory.yml -a "subscription-manager attach --pool=xxx"
```

## OpenShiftをインストールする

```bash
ansible-playbook -i ./inventory.yml /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml
ansible-playbook -i ./inventory.yml /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml
```

## OpenShiftにアクセスできるよう、hostsファイルを登録する

ローカルマシンのhostsファイルを編集し、OpenShiftの管理コンソールにアクセス出来るようにします。

プロジェクトのディレクトリで `terraform output hosts_file` を実行し、hostsに追加する内容を確認できます。

```bash
terraform output hosts_file
# => xx.xx.xx.xx master.ocp.example.com

sudo vi /etc/hosts
xx.xx.xx.xx master.ocp.example.com
```

## OpenShiftがインストールされたことを確認する

以下にアクセスして、OpenShiftのコンソール画面が出てくることを確認してください。

https://master.ocp.example.com:8443

ログインのユーザー名、パスワードは admin/adminを使用してください。
(任意のユーザー名、パスワードでログイン出来ます。)
