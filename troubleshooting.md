# Takıldığım Yerler

Projeyi bir günde bitirmeyi planlamıştım. Dört yerde takıldım ve toplamda birkaç saatimi aldı. Aşağıda her birini, doğru teşhise nasıl vardığımı ve yolda ne öğrendiğimi yazdım.

---

## 1. EFS mount olmuyordu — NXDOMAIN

**Belirti**

EFS'i oluşturdum, mount etmeye çalıştım:

```
Failed to resolve "fs-xxxx.efs.eu-central-1.amazonaws.com"
Attempting to lookup mount target ip address using botocore.
Failed to import necessary dependency botocore
```

**Ne kontrol ettim**

Önce hata mesajının söylediği şeylere baktım. File system ID doğruydu, konsoldan kopyalamıştım. Region doğruydu, EC2 ve EFS ikisi de `eu-central-1`'deydi. Mount target'lara baktım, ikisi de `Available` durumda, doğru VPC'de, doğru security group bağlı.

Sonra sorunu izole etmek için mount'u bırakıp sadece DNS'i test ettim:

```bash
nslookup fs-xxxx.efs.eu-central-1.amazonaws.com
```

```
** server can't find fs-xxxx.efs.eu-central-1.amazonaws.com: NXDOMAIN
```

VPC'nin kendi DNS sunucusu bu ismi hiç tanımıyordu. Yani sorun mount komutunda değil, DNS katmanındaydı.

**Sebep**

VPC'de **DNS hostnames** ayarı kapalıydı.

Kafa karıştıran şey şu: VPC'de iki ayrı DNS ayarı var. `enableDnsSupport` (DNS resolution) açıktı — o yüzden makine `google.com`'u çözebiliyor, `dnf install` çalışıyordu. Ama `enableDnsHostnames` kapalıydı ve AWS servis DNS'lerinin (EFS, RDS endpoint gibi) VPC içinde çözümlenmesi için **her ikisinin de** açık olması gerekiyor.

Custom VPC'lerde bu ayar default kapalı geliyor, default VPC'de açık. Ben custom VPC kurduğum için farkında olmadan kapalı bırakmışım.

**Çözüm**

VPC → Actions → Edit VPC settings → Enable DNS hostnames.

Birkaç dakika sonra `nslookup` bir IP döndürdü, mount sorunsuz oldu.

**Not:** Aynı hatayı VPCB'de de yaptım, orada da Windows makinenin Public DNS'i boş göründü. İki VPC kurarken ayarları birinde yapıp diğerinde unutmak kolay.

---

## 2. NLB'ye kendi target'ından erişilemiyor

**Belirti**

NLB'yi kurdum, target group healthy görünüyordu ama VPCA'daki EC2'den erişemiyordum:

```bash
curl -I http://www.proje.local
# timeout
curl -I http://10.100.11.40   # NLB'nin private IP'si
# timeout
```

**Ne kontrol ettim**

Bu, epey vaktimi alan kısım oldu çünkü yanlış yerde arıyordum.

NLB'nin listener'ına baktım — TCP:80 vardı, doğru target group'a forward ediyordu. Target group'a baktım — 1 target, healthy, port 80, doğru AZ'de. Security group'a baktım. NACL'lere baktım, ikisi de tamamen açıktı. Cross-zone load balancing'i açtım, değişmedi. NLB'yi silip yeniden kurdum, yine olmadı.

Her katman doğru görünüyordu ama trafik geçmiyordu.

**Sebep**

Test yaptığım EC2, NLB'nin **kendi target'ıydı**.

NLB instance target type'ta client IP'sini koruyor. Ben `wordpressServer`'dan NLB'ye istek atınca, NLB o isteği yine aynı makineye yönlendiriyordu. Paket şöyle görünüyordu:

```
Kaynak: 10.100.0.43 (wordpressServer)
Hedef:  10.100.0.43 (wordpressServer)
```

Makine kendi gönderdiği paketi kendi alıyor, tanıyamıyor ve sessizce düşürüyor. Buna hairpinning/loopback deniyor ve NLB'de bilinen bir kısıt. ALB'de bu sorun yok çünkü ALB client IP'sini korumuyor.

**Çözüm**

Testi NLB'nin target'ı olmayan bir makineden yaptım — VPCB'deki Windows'tan.

**Ders**

Test ettiğin makine, test ettiğin sistemin parçası olmamalı. Bu, sadece NLB için değil genel bir kural: bir sistemin içinden o sistemi test etmek yanıltıcı sonuç verir.

---

## 3. Internet-facing NLB, peered VPC'den erişilemiyor

**Belirti**

VPCB'deki Windows'tan `www.proje.local`'a gittiğimde `ERR_CONNECTION_TIMED_OUT` alıyordum.

**Ne kontrol ettim**

Önce DNS'in çözülüp çözülmediğine baktım:

```powershell
nslookup www.proje.local
# Address: 63.179.222.229
```

Bu bir **public IP**. Halbuki NLB VPCA'da ve ben private IP bekliyordum.

**Sebep**

NLB'yi Internet-facing olarak kurmuştum. Internet-facing NLB'nin hem public hem private IP'si oluyor.

Route 53 alias kaydı, sorguyu **kimin sorduğuna göre** farklı cevap veriyor:

- VPCA'dan sorulunca private IP dönüyor
- VPCB'den sorulunca **public IP** dönüyor

Çünkü AWS, peered VPC'yi "NLB'nin kendi VPC'si" saymıyor, dışarıdan bir sorgu gibi değerlendiriyor.

Public IP'ye giden trafik peering'den geçmez. VPCB'nin internet gateway'inden çıkıp NLB'nin public arayüzüne ulaşmaya çalışıyor, dönüş yolunda kopuyor.

**Çözüm**

NLB'yi **Internal** scheme ile yeniden oluşturdum. Internal NLB'nin public IP'si olmadığı için, artık her iki VPC'den de private IP dönüyor ve trafik peering üzerinden akıyor.

**Ders**

Peering senaryolarında load balancer Internal olmalı. Zaten projenin ihtiyacı VPC içi erişimdi, Internet-facing gereksizdi.

---

## 4. Asıl sorun: Security Group'un outbound'u

**Belirti**

NLB'yi Internal'a çevirdim, DNS artık private IP döndürüyordu. Ama VPCB'den hâlâ hiçbir şeye ulaşamıyordum:

```powershell
Test-NetConnection www.proje.local -Port 80
# TcpTestSucceeded : False

Test-NetConnection 10.100.0.43 -Port 80   # doğrudan EC2'ye
# TcpTestSucceeded : False

ping 10.100.0.43
# timeout
```

Ping bile geçmiyordu. Bu, trafiğin hiç ulaşmadığını gösteriyordu.

**Ne kontrol ettim**

Sistematik olarak her katmanı eledim:

| Katman | Durum |
|---|---|
| Peering connection | Active, CIDR'lar çakışmıyor, aynı region |
| VPCA route table'ları | `10.200.0.0/16 → pcx-xxx` var (hem public hem private) |
| VPCB route table'ı | `10.100.0.0/16 → pcx-xxx` var |
| VPCA NACL | 100 numaralı kural her şeye izin veriyor |
| VPCB NACL | Aynı şekilde açık |
| Hedef SG (`Ec2SecGroup`) | HTTP, SSH, ICMP hepsi `0.0.0.0/0` |
| Windows Firewall | Kapattım, değişmedi |
| NLB yapılandırması | Listener, target group, cross-zone kontrol edildi |

Her şey doğruydu ama trafik geçmiyordu. Bu noktada gerçekten tıkandım.

Sonra şunu fark ettim: Windows makine kendi VPC'si içinde ping atabiliyordu (`10.200.0.2`'ye cevap geliyordu), ama VPCA'ya hiçbir şey geçmiyordu. Yani makine paket üretebiliyordu, ama belirli bir yöne gidemiyordu.

O zaman kaynak makinenin SG'sine baktım — o ana kadar sadece **hedefin** SG'sini kontrol etmiştim.

**Sebep**

`RDPsecGroup`'un outbound kuralı:

```
Type: RDP, Protocol: TCP, Port: 3389, Destination: 0.0.0.0/0
```

Sadece bu. Security Group'larda outbound normalde "All traffic" olarak default gelir, ama bu SG'de kısıtlanmıştı. Windows makinesi **3389 dışında hiçbir porta paket gönderemiyordu.**

Bu yüzden:
- Port 80'e giden TCP paketleri çıkamıyordu
- ICMP (ping) çıkamıyordu
- Ama RDP çalışıyordu, çünkü tek izinli port oydu

**Çözüm**

Outbound kuralını `All traffic → 0.0.0.0/0` yaptım. Anında çalıştı.

**Ders**

Bu en pahalı hatam oldu, birkaç saat sürdü. Çıkardığım ders: bağlantı sorunlarında **hem hedefin inbound'una hem kaynağın outbound'una** bakmak gerekiyor.

Herkes (ben dahil) refleks olarak hedefin inbound kurallarına bakıyor, çünkü genelde sorun orada oluyor. Ama outbound'un kısıtlandığı bir durumda, hedefte ne yaparsanız yapın trafik zaten çıkamıyor.

---

## Genel çıkarım

Dört sorunun ortak noktası şu: her seferinde **doğru soruyu sormak**, doğru cevabı bulmaktan daha zordu.

Mount çalışmadığında "mount neden çalışmıyor" diye değil, "DNS çözülüyor mu" diye sorunca bulundu. NLB'ye erişilemediğinde "NLB'de ne yanlış" diye değil, "test ettiğim yer doğru mu" diye sorunca bulundu. Bağlantı kurulamadığında "hedefte ne engelliyor" diye değil, "kaynak paket gönderebiliyor mu" diye sorunca bulundu.

Bir dahaki sefere daha erken **VPC Flow Logs** açacağım. Trafiğin nerede kesildiğini tahmin etmek yerine doğrudan görmek, elemeyi çok kısaltırdı.
