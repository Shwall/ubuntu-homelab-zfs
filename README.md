# ubuntu-homelab-zfs

Ubuntu Server 26.04 **autoinstall (ZFS on root)** + an **Ansible role** that turns the fresh install into a
Docker host running **Frigate**, **Home Assistant** (+ Mosquitto) and **Nextcloud AIO**.

```
autoinstall/            user-data, meta-data, build-seed-iso.sh   -> unattended ZFS install
site.yml / local.yml    push-mode and local (first-boot) playbooks
group_vars/all.yml      the file you edit
roles/homelab/          ZFS datasets, Docker (zfs driver), ufw, sanoid, 4 compose stacks
```

## 1. Prepare
1. Fork/push this repo to GitHub (private is best if you put camera URLs in `group_vars`).
2. Edit `autoinstall/user-data`: password hash, SSH key, target disk `serial`/`path`, repo URL, secrets block.
3. Edit `group_vars/all.yml` (timezone, GPU, Frigate cameras, ...).

## 2. Install
```bash
./autoinstall/build-seed-iso.sh        # -> autoinstall/seed.iso (label "cidata")
```
Boot the Ubuntu Server 26.04 ISO with `seed.iso` attached as a second CD/disk (or a second USB stick formatted
FAT32/ISO with label `CIDATA` holding `user-data` + `meta-data`). At the GRUB menu press `e`, append
`autoinstall` to the `linux` line, boot. Without that word the installer pauses for a "yes" confirmation.

The installer wipes the matched disk, builds `bpool`/`rpool`, creates the `ansible` user and reboots. On first
boot a one-shot service clones this repo and runs `local.yml`. Watch it with
`tail -f /var/log/homelab-bootstrap.log`; re-run with `sudo systemctl start homelab-bootstrap`
(delete `/var/lib/homelab/bootstrap.done` first if it already completed).

### Or push from your laptop instead
```bash
ansible-galaxy collection install -r requirements.yml
cp inventory/hosts.yml.example inventory/hosts.yml   # edit IP
ansible-playbook -i inventory/hosts.yml site.yml
# subsets: --tags zfs | docker | frigate | homeassistant | nextcloud | snapshots
```
(Remove the bootstrap `write_files`/`runcmd` from `user-data` if you only want push mode.)

## 3. After the run
| Service | URL | Notes |
|---|---|---|
| Home Assistant | `http://<ip>:8123` | onboarding wizard; add MQTT integration -> host `localhost:1883`, user `frigate_ha`, password in `/etc/homelab/mqtt_password` |
| Frigate | `https://<ip>:8971` | admin password is printed once in `docker logs frigate`; edit cameras in `/srv/homelab/frigate-config/config.yml` |
| Nextcloud AIO | `https://<ip>:8080` | shows a passphrase on first visit; AIO needs a real domain for its Apache/TLS (or `nextcloud_behind_proxy: true` + your reverse proxy -> port 11000) |

## ZFS layout created
```
rpool/homelab                    -> /srv/homelab
rpool/homelab/homeassistant      snapshotted (sanoid)
rpool/homelab/mosquitto          snapshotted
rpool/homelab/frigate-config     snapshotted
rpool/homelab/frigate-media      recordsize=1M, no compression, not snapshotted
rpool/homelab/nextcloud-data     snapshotted (AIO NEXTCLOUD_DATADIR)
rpool/docker                     -> /var/lib/docker (Docker zfs storage driver)
```
Got extra disks? Set `homelab_data_pool` (`create: true`, by-id devices) and `homelab_pool: tank`.
Pool creation is skipped if the pool already exists and fails on disks that carry old signatures (no `-f`).

## Things worth knowing
* **Docker + ZFS:** Docker's `overlay2` driver refuses ZFS, so the role uses the native `zfs` driver on a dedicated
  dataset. Expect many `rpool/docker/<hash>` child datasets; that is normal. Changing driver later hides existing images.
* **ufw and Docker:** published container ports bypass ufw. Filter on your router/VLAN if that matters.
* **Frigate config** is seeded once and never overwritten (`frigate_config_overwrite: false`) so UI edits survive.
* **Secrets:** keep them in `/etc/homelab/secrets.yml` (written by cloud-init, 0600) or ansible-vault, not in git.
* **Nextcloud AIO** manages its own child containers and has built-in Borg backups; sanoid snapshots of
  `nextcloud-data` are a complement, not a replacement (AIO's database lives in Docker volumes).
* **Verify before trusting:** this was written without access to a 26.04 install. Check the pinned items against
  current docs: Frigate config schema (`docs.frigate.video`), the Nextcloud AIO compose example, and that
  `docker.io`/`docker-compose-v2` exist in the 26.04 archive.
