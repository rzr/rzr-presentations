#!/usr/bin/make -f

default: help all
	@sync

target=index
reveal_url?=https://github.com/hakimel/reveal.js/
reveal_zip_url?=https://github.com/hakimel/reveal.js/archive/master.zip
web_url?=https://${USER}.github.io/${USER}-example/
licence_url?=https://licensedb.org/id/CC-BY-SA-4.0.txt

srcs?=index.org
srcs+=$(wildcard docs/index.org)
srcs+=$(wildcard docs/*/index.org)
objs?=${srcs:.org=.html}
static_dir?=./static
make?=make -f ${CURDIR}/Makefile

help:
	@echo "# Usage: "
	@echo "# make upload # to build and publish"
	@echo "# srcs=${srcs}"
	@echo "# objs=${objs}"
	@echo "https://github.com/yjwen/org-reveal/issues/171"



all: LICENSE ${objs}
	ls $^

%.html: %.org Makefile
	cd ${<D} \
&& \
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

clean:
	rm -rfv *~ */*/*~ tmp

cleanall: clean
	find . -iname "*.html" -exec rm -v "{}" \;
	find . -iname "*.lst" -exec rm -v "{}" \;

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
	-grep -o -e 'https\?://[^]"]*' -- "$<" \
 | grep -E ".**\.(gif|png|svg|jpg|jpeg|webm|mp4)"\
 | sort -u >> "$@.tmp"
	mv "$@.tmp" "$@"


${target}.org._static.org: ${target}.lst static reveal.js
	sed -e 's|#+REVEAL_ROOT:.*|#+REVEAL_ROOT: ${CURDIR}/reveal.js|g' \
  < ${target}.org > $@.tmp
	sort -u $< | while read url; do \
    sed -e "s|$${url}|${static_dir}/$${url}|g" \
      -e "s|${static_dir}/http://|${static_dir}/http/|g" \
      -e "s|${static_dir}/https://|${static_dir}/https/|g" \
      -i "${@}.tmp" ; \
  done
	mv "${@}.tmp" "$@"
#	cp -av "$@" ${<D}/static/${<F}.org
	grep http "$@"

html-static: ${target}.org ${target}.org._static.org
	make html target="${<}._static"
	sed -e "s|#./|/./|g" -i "${<}._static.html"

org/online: 
	sort -u $< | while read url; do \
      sed \
        -e "s|${static_dir}/http/|http://|g" \
        -e "s|${static_dir}/https/|https://|g"\
	-e "s|${static_dir}/$${url}|$${url}|g" \
        -i "${target}.org" ;\
  done
	grep http "${target}.org"


cache: Makefile download
	${MAKE} org/offline
	${MAKE} html

offline:
	git checkout $@/master
	make all/cache

static: ${target}.lst Makefile
	mkdir -p "${<D}/static"
	cd "${<D}/static" && \
  cat "${CURDIR}/$<" | while read url ; do \
    ${make} $${url}/curl || exit $? ; \
  done

dl:
	make all/static
	git add .
	-git commit -am 'deploy: Cache downloaded files, see lst file for sources'


html: ${target}.html
	ls $<

all/%: ${srcs}
	for src in $^ ; do \
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
	-git commit -sam "WIP: About to deploy ${target}"
	git checkout ${deploy_branch} \
  || git checkout -b ${deploy_branch} master
	make html
	git add .
	-git commit -am "WIP: Generated html ${target}"
	git checkout master


upload:
	git checkout master
	git branch -D ${deploy_branch}
	${MAKE} all/deploy
	${MAKE} deploy target=./docs/index
	${MAKE} deploy
	git checkout ${deploy_branch}
	echo "# About to push to origin in 5 secs ?"
	sleep 5 ; git push -f origin HEAD:gh-pages
	git checkout master

start: ${target}.html
	x-www-browser $<

start/objs: ${target}.html ${objs}
	x-www-browser $<

%/curl:	
	ls "${@D}" > /dev/null 2>&1 \
 || curl --create-dirs -o "./${@D}" -- "${@D}"
	ln -fs http: http
	ln -fs https: https
	find . -iname "*#*" | while read file; do \
    basename=$$(basename -- "$${file}"); \
    dirname=$$(dirname -- "$${file}"); \
    dstname=$$(echo "$${basename}" | sed -e 's|#.|%23.|g'); \
    ln -fs "$${basename}" "$${dirname}/$${dstname}"; \
    dstname=$$(echo "$${basename}" | sed -e 's|#.||g'); \
    ln -fs "$${basename}" "$${dirname}/$${dstname}"; \
  done

offline: all/html-static
	${MAKE} start target="index.org._static"
