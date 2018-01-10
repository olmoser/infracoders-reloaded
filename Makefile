INFRACODERS_DOMAIN ?= prometheus.exokube.eu

generate-infra:
	terraform plan; \
	echo "Proceed with terraforming? (y/N)"; \
	read -n1 proceed; \
	if [ "$$proceed" == "y" ]; then \
		terraform apply; \
	fi \

destroy-infra:
	@echo "\033[31m!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" ;\
	echo ;\
	echo  "WARNING: You are about to destroy your infrastructure. Proceed with care!" ;\
	echo ;\
	echo  "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" ;\
	echo
	echo "Proceed with destruction? (y/N)"; \
	read -n1 proceed; \
	if [ "$$proceed" == "y" ]; then \
		terraform destroy; \
	fi \

generate-dns:
	@echo  "\033[33mNOTE: Please make sure that your infrastructure was successfully terraformed before generating the DNS resource!" ;\
	echo  "\033[33mNOTE: Also make sure to set INFRACODERS_DOMAIN to the desired domain (Using: $(INFRACODERS_DOMAIN))" ;\
	tput sgr0 ; \
	echo ; \
	read -p "Enter filename (e.g. dns.tf) or '-' for STDOUT: " filename; \
	dns=`generate_inventory.py --dns --domain=$(INFRACODERS_DOMAIN)`; \
	if [ "$$filename" == "-" ]; then \
		echo "$$dns" ;\
	else 	\
		echo "$$dns" > $$filename ; \
	fi \
