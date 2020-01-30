#!/usr/bin/make -f

default: help all

target=index
NAME=$(shell grep 'TITLE:' ${target}.org | cut -d':' -f2)
#NAME=https://purl.org/rzr/
reveal_url?=https://github.com/hakimel/reveal.js/
reveal_zip_url?=https://github.com/hakimel/reveal.js/archive/master.zip
web_url?=https://${USER}.github.io/${USER}-example/
licence_url?=https://licensedb.org/id/CC-BY-SA-4.0.txt

srcs?=index.org
srcs+=$(wildcard docs/index.org)
srcs+=$(wildcard docs/*/index.org)
objs?=${srcs:.org=.html}
cache?=./url


all: LICENSE ${objs}
	ls $^

%.html: %.org %.lst Makefile
	cd ${<D} \
&& \
 NAME="${NAME}" \
 emacs \
 --no-init-file  \
 --batch \
 -u "${USER}" \
 --eval="(require 'org)" \
 --eval="(require 'org-gnus)" \
 --eval="(require 'ox-reveal)" \
 --find-file "${<F}" \
 --funcall org-reveal-export-to-html \
 2> /dev/null

%.pdf: %.org %.lst Makefile
	cd ${<D} \
&& \
 NAME="${NAME}" \
 emacs \
 --no-init-file  \
 --batch \
 -u "${USER}" \
 --eval="(require 'org)" \
 --eval="(require 'org-gnus)" \
 --eval="(require 'ox-reveal)" \
 --find-file "${<F}" \
 --funcall org-reveal-export-to-pdf \
 2> /dev/null


run: ${target}.html
	x-www-browser "$<"
help:
	@echo "# NAME=${NAME}"
	@echo "# srcs=${srcs}"
	@echo "# objs=${objs}"
	@echo "https://github.com/yjwen/org-reveal/issues/171"

clean:
	rm -rfv *~ */*/*~ tmp

cleanall: clean
	find . -iname "*.html" -exec rm -v "{}" \;

setup/debian:
	sudo apt-get install wget emacs sudo unzip git

setup: setup/debian
	emacs \
 --no-init-file  \
 --batch \
 -u "${USER}" \
 --eval="(package-refresh-contents)" \
 --eval="(package-install 'htmlize)" \
 --eval="(package-install 'ox-reveal)" \
 # EOL


config: reveal.js
	rm -f resources.lst *~

tmp/reveal.js:
	git submodule update \
	|| git submodule add ${reveal_url} --depth 1 -b master

reveal.js:
	wget -O- ${reveal_zip_url} > tmp.zip && unzip tmp.zip \
 && mv reveal.js-master reveal.js


test:
	x-www-browser ${web_url}

LICENSE:
	@echo "Update ${CURDIR}/Makefile to setup licence"
	@echo "Fetching default one at:"
	@echo "URL: ${licence_url}"
	wget -O $@ "${licence_url}"

%.lst: %.org Makefile
	echo "" > "$@"
	-grep -o -e '\[\[http[^]]*\]\]' $< | sed -e 's|^\[\[\(.*\)\]\]|\1|g' | grep -v '*/' | grep .png >> $@
	-grep -o -e '\[\[http[^]]*\]\]' $< | sed -e 's|^\[\[\(.*\)\]\]|\1|g' |grep -v '*/' | grep .svg >> $@
	sort "$@" | uniq > "$@.tmp" && mv "$@.tmp" "$@"

offline: ${target}.org Makefile online download
	@mkdir -p ${<D}/${cache} && \
 cd ${<D}/${cache} && \
 ln -fs .  http: && \
 ln -fs .  https: && \
 ln -fs .  http && \
 ln -fs .  https
	sed \
 -e "s|\[\[http://|\[\[${cache}/http/|g" \
 -e "s|\[\[https://|\[\[${cache}/https/|g" \
 -i $<

online: ${target}.org
	-sed \
 -e "s|\[\[${cache}/http/|\[\[http://|g" \
 -e "s|\[\[${cache}/https/|\[\[https://|g" \
 -i $<


download: ${target}.lst Makefile
	@mkdir -p ${<D}/${cache} && \
 cd ${<D}/${cache} && \
 wget -p -i "${CURDIR}/${<}"

html: ${target}.html
	ls $<

all/%: ${srcs}
	for src in $^ ; do  \
 dir=$$(dirname -- "$${src}") ; \
 make target="$${dir}/index" ${@F} \
 || exit $$? ; \
 done

obsolete/deploy: all reveal.js
	-git add .
	-git commit -sam 'WIP'
	git push origin -f  HEAD:gh-pages


deploy_branch?=gh-pages

deploy:
	-git checkout master
	make cleanall
	-git commit -am 'WIP: About to deploy'
	-git branch -D ${deploy_branch}
	git checkout -b ${deploy_branch} master
	make all
	git add .
	-git commit -am 'deploy: Generated files'
	make all/download
	git add .
	-git commit -am 'deploy: Cache downloaded files, see lst file for sources'
	echo "# About to push to origin in 5 secs ?"
	sleep 5 ; git push -f origin HEAD:gh-pages
	git checkout master

start: ${target}.html ${objs}
	x-www-browser $<
