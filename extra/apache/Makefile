DIR = $(HOME)/dotfiles/extra/apache

.PHONY: all
all:
	cp $(DIR)/httpd.conf /etc/apache2/httpd.conf
	cp $(DIR)/extra/httpd-userdir.conf /etc/apache2/extra/httpd-userdir.conf
	cp $(DIR)/users/kenjisato.conf /etc/apache2/users/kenjisato.conf
	apachectl restart 