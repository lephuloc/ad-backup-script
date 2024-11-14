# Active Directory Backup Script

Script PowerShell tự động hóa việc backup các dịch vụ Active Directory bao gồm DHCP, DNS, Group Policy và AD Objects.

## Tính năng

- Backup toàn bộ cấu hình DHCP Server
- Backup các zone DNS 
- Backup tất cả Group Policy Objects (GPOs)
- Backup các đối tượng Active Directory (Users, Groups, OUs, Computers)
- Tạo báo cáo chi tiết cho mỗi lần backup
- Hỗ trợ đầy đủ tiếng Việt
- Tự động xử lý encoding UTF-8

## Yêu cầu

- Windows Server với Active Directory Domain Services
- PowerShell 5.1 trở lên
- Các module PowerShell sau:
  - ActiveDirectory
  - GroupPolicy
  - DhcpServer
  - DnsServer

## Cài đặt

1. Clone repository này về máy chủ Domain Controller:
```powershell
git clone https://github.com/yourusername/ad-backup-script.git
```

2. Đảm bảo các module cần thiết đã được cài đặt:
```powershell
Import-Module ActiveDirectory
Import-Module GroupPolicy
Import-Module DhcpServer
Import-Module DnsServer
```

## Sử dụng

1. Mở PowerShell với quyền Administrator
2. Di chuyển đến thư mục chứa script:
```powershell
cd path\to\script
```

3. Chạy script:
```powershell
.\backup_custom.ps1
```

4. Làm theo các hướng dẫn trên màn hình:
   - Chọn thư mục để lưu backup
   - Nhập tên domain (hoặc Enter để sử dụng domain hiện tại)

## Cấu trúc thư mục backup

```
ADBackup_domain_timestamp/
├── AD/
│   ├── ad_users.xml
│   ├── ad_groups.xml
│   ├── ad_ous.xml
│   ├── ad_computers.xml
│   └── ad_summary.json
├── DHCP/
│   ├── dhcp_backup.xml
│   └── dhcp_scopes.xml
├── DNS/
│   └── [zone_name].txt
├── GPO/
│   ├── {GPO_ID}/
│   └── gpo_summary.csv
└── backup_report.txt
```

## Báo cáo

Sau mỗi lần backup, script sẽ tạo một file báo cáo chi tiết (backup_report.txt) bao gồm:
- Thời gian backup
- Domain được backup
- Số lượng đối tượng được backup cho mỗi thành phần
- Trạng thái backup của từng thành phần

## Xử lý lỗi

Script bao gồm cơ chế xử lý lỗi toàn diện:
- Kiểm tra trạng thái các service trước khi backup
- Tiếp tục thực hiện nếu một thành phần thất bại
- Ghi log chi tiết các lỗi phát sinh
- Thông báo rõ ràng về trạng thái của từng bước

## Đóng góp

Mọi đóng góp đều được chào đón! Hãy tạo pull request hoặc báo cáo issues nếu bạn có bất kỳ đề xuất nào.

## License

MIT License

## Tác giả

- Tên tác giả
- Email liên hệ
- Website

## Ghi chú

- Script nên được chạy trên Domain Controller chính
- Đảm bảo có đủ quyền admin để thực hiện các thao tác backup
- Nên lập lịch chạy script định kỳ để backup tự động
