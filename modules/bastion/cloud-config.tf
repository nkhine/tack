resource "template_file" "cloud-config" {

  template = <<EOF
#cloud-config

---
coreos:

  etcd2:
    discovery-srv: ${ internal-tld }
    peer-trusted-ca-file: /etc/kubernetes/ssl/ca.pem
    peer-client-cert-auth: true
    peer-cert-file: /etc/kubernetes/ssl/kz8s-bastion.pem
    peer-key-file: /etc/kubernetes/ssl/kz8s-bastion-key.pem
    proxy: on

  units:
    - name: sshd.socket
      command: restart
      runtime: true
      content: |
        [Socket]
        ListenStream=2222
        FreeBind=true
        Accept=yes
    - name: etcd2.service
      command: start
    - name: s3-get-presigned-url.service
      command: start
      content: |
        [Unit]
        After=network-online.target
        Description=Install s3-get-presigned-url
        Requires=network-online.target
        [Service]
        ExecStartPre=-/usr/bin/mkdir -p /opt/bin
        ExecStart=/usr/bin/curl -L -o /opt/bin/s3-get-presigned-url \
          https://github.com/kz8s/s3-get-presigned-url/releases/download/v0.1/s3-get-presigned-url_linux_amd64
        ExecStart=/usr/bin/chmod +x /opt/bin/s3-get-presigned-url
        RemainAfterExit=yes
        Type=oneshot

    - name: get-ssl.service
      command: start
      content: |
        [Unit]
        After=s3-get-presigned-url.service
        Description=Get ssl artifacts from s3 bucket using IAM role
        Requires=s3-get-presigned-url.service
        [Service]
        ExecStartPre=-/usr/bin/mkdir -p /etc/kubernetes/ssl
        ExecStart=/bin/sh -c "/usr/bin/curl $(/opt/bin/s3-get-presigned-url \
          ${ region } ${ bucket } ${ ssl-tar }) | tar xv -C /etc/kubernetes/ssl/"
        RemainAfterExit=yes
        Type=oneshot

  update:
    reboot-strategy: etcd-lock
EOF

  vars {
    bucket = "${ var.bucket-prefix }"
    internal-tld = "${ var.internal-tld }"
    region = "${ var.region }"
    ssl-tar = "/ssl/k8s-worker.tar"
  }
}
