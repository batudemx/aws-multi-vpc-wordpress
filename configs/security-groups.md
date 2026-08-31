# Security Group Kuralları

Projedeki en önemli tasarım kararı, kaynak olarak IP yerine **başka bir Security Group'un ID'sini** kullanmaktı.

---

## VPCA — `10.100.0.0/16`

### Ec2SecGroup

Uygulama sunucuları (ASG'nin açtığı EC2'ler) bu SG'yi kullanıyor.

| Yön | Type | Port | Kaynak / Hedef |
|---|---|---|---|
| Inbound | HTTP | 80 | `0.0.0.0/0` |
| Inbound | SSH | 22 | `0.0.0.0/0` |
| Inbound | All ICMP - IPv4 | All | `0.0.0.0/0` |
| Outbound | All traffic | All | `0.0.0.0/0` |

ICMP kuralı test amaçlı eklendi — ping ile bağlantı doğrulaması yapabilmek için. Production'da kapatılır.

### NFSSecGroup

EFS mount target'larına bağlı.

| Yön | Type | Port | Kaynak |
|---|---|---|---|
| Inbound | NFS | 2049 | **`Ec2SecGroup`** |
| Outbound | All traffic | All | `0.0.0.0/0` |

### RDSSecGroup

RDS instance'ına bağlı.

| Yön | Type | Port | Kaynak |
|---|---|---|---|
| Inbound | MySQL/Aurora | 3306 | **`Ec2SecGroup`** |
| Outbound | All traffic | All | `0.0.0.0/0` |

---

## VPCB — `10.200.0.0/16`

### RDPsecGroup

Windows Server'a bağlı.

| Yön | Type | Port | Kaynak / Hedef |
|---|---|---|---|
| Inbound | RDP | 3389 | `0.0.0.0/0` |
| Outbound | **All traffic** | **All** | **`0.0.0.0/0`** |

Outbound satırı kalın çünkü bu, projede saatlerce süren bir soruna sebep oldu. Detaylar aşağıda.

---

## Neden SG referansı, IP değil

`NFSSecGroup`'ta kaynak olarak bir IP yazsaydım, ASG yeni bir makine açtığında (farklı private IP alacak) o makine EFS'e erişemezdi. Her yeni instance için kuralı elle güncellemem gerekirdi.

SG referansı kullanınca: `Ec2SecGroup`'a sahip **her** makine otomatik olarak izinli oluyor. ASG 2'den 4'e çıksa da, makineler değişse de kural bir kere yazıldı, sonsuza kadar geçerli.

```
İnternet
   ↓ HTTP 80, SSH 22
Ec2SecGroup → EC2 (public subnet)
   ↓ NFS 2049                        ↓ MySQL 3306
   ↓ (kaynak: Ec2SecGroup)           ↓ (kaynak: Ec2SecGroup)
NFSSecGroup → EFS                 RDSSecGroup → RDS
   (private subnet)                  (private subnet)
```

EFS ve RDS iki katmanla korunuyor: hem private subnet'te oldukları için internetten fiziksel bir yol yok, hem de SG seviyesinde sadece belirli bir SG'den gelen trafiğe izin veriliyor.

---

## Outbound kuralı — dikkat

Security Group'larda outbound normalde `All traffic → 0.0.0.0/0` olarak default gelir. Ama bu SG'lerden birinde (`RDPsecGroup`) outbound kısıtlanmıştı, sadece port 3389'a izin veriyordu.

Sonuç: Windows makinesi RDP dışında **hiçbir porta paket gönderemiyordu**. Ne HTTP (80), ne ICMP (ping). Hedefteki `Ec2SecGroup` tamamen açık olmasına rağmen trafik hiç ulaşmıyordu, çünkü kaynak makineden hiç çıkmıyordu.

Teşhis süreci ve nasıl bulunduğu [troubleshooting.md](../troubleshooting.md#4-asıl-sorun-security-groupun-outboundu) dosyasında.

**Çıkarılan ders:** Bağlantı sorunlarında sadece hedefin inbound kurallarına değil, kaynağın outbound kurallarına da bakmak gerekiyor.

---

## CLI ile mevcut kuralları görüntüleme

```bash
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=<VPC_ID>" \
  --query "SecurityGroups[].{Name:GroupName,Inbound:IpPermissions,Outbound:IpPermissionsEgress}" \
  --output json
```
