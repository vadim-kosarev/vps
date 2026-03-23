Сертификаты хранятся на сервере в /root/cert/ и не коммитятся в git.

Ожидаемые файлы:
  agghhh.click_fullchain.crt  — полная цепочка сертификата
  agghhh.click_privatekey.key — приватный ключ

Сертификат выпущен через acme.sh (Let's Encrypt):
  /root/.acme.sh/agghhh.click_ecc/

Обновить:
  sudo acme.sh --renew -d agghhh.click --ecc
  sudo cp /root/.acme.sh/agghhh.click_ecc/fullchain.cer /root/cert/agghhh.click_fullchain.crt
  sudo cp /root/.acme.sh/agghhh.click_ecc/agghhh.click.key /root/cert/agghhh.click_privatekey.key

