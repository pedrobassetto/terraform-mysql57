#### Matéria Infrastructure and Cloud Computing do MBA - Engenharia de Software
#### Aluno: Pedro Eduardo Bassetto 

#### Atividade 2 - Terraform
Subir uma máquina virtual no Azure, AWS ou GCP instalando o MySQL e que esteja acessível no host da máquina na porta 3306, usando Terraform.  

- [x] Criação: Resource Group -> rgAtvTerraform
- [x] Criação: Virual Network -> atv-network
- [x] Criação: Subnet -> internal
- [x] Criação: Public Ip -> atv-public-ip
- [x] Criação: Network security -> atv-firewall (Liberada para portas 22 e 3306)
- [x] Criação: Network interface -> atv-nic
- [x] Criação: Virtual Machine -> atv-vm
- [x] Config: Null Resource -> upload (Upload do arquivo de configuração Mysql) 
- [x] Config: Null Resource -> install (Apt Update e Install Mysql 5.7) 