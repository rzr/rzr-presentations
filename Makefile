#!/usr/bin/make -f
# -*- makefile -*-
# ex: set tabstop=4 noexpandtab:
# -*- coding: utf-8 -*-
#
# SPDX-License: ISC
# SPDX-License-URL: https://spdx.org/licenses/ISC.html

default: help all
	@echo "# https://github.com/yjwen/org-reveal"

project?=rzr-presentations
PORT?=8888

srcs?=$(wildcard *.org | sort)
srcs+=$(wildcard docs/*.org | sort)
srcs+=$(wildcard docs/*/*.org | sort)

objs?=${srcs:.org=.html}
target?=$(shell echo ${srcs:.org=} | tr ' ' '\n' | head -n1)
reveal_url?=https://github.com/hakimel/reveal.js/
reveal_zip_url?=https://github.com/hakimel/reveal.js/archive/master.zip
reveal_dir?=./reveal.js
sudo?=sudo
deploy_dir?=tmp/deploy
output_branch?=gh-pages
cache_dir?=./cache/url
make?=make -f ${CURDIR}/Makefile
url?=https://rzr.github.io/rzr-presentations
width?=1920
height?=1080
suffix?=/0/


help:
	@echo "# Usage:"
	@echo "#  make help # Usage"
	@echo "#  make setup # Install tools"
	@echo "#  make all # Build html"
	@echo "#  make docker # Build and serve from docker"
	@echo "#  make start # View HTML in Web browser"
	@echo "#  make download # Download deps"
	@echo "#  make offline # Cache inlined resources and generate cached pages"
	@echo "#  make upload # to build and publish"
	@echo "#  make setup/debian setup download start # ..."
	@echo "# Config:"
	@echo "#  srcs=${srcs}"
	@echo "#  objs=${objs}"
	@echo "#  target=${target}"

all: ${objs}
	ls $^

build: ${target}.html
	ls $^

download: ${reveal_dir}
	ls $^

start: ${target}.html
	x-www-browser "$<#${suffix}"

clean:
	rm -rfv *~ */*/*~ tmp tmp.*

cleanall: clean
	find . -iname "*.html" -exec rm -v "{}" \;

setup/debian: /etc/debian_version
	-${sudo} apt-get update
	${sudo} apt-get install -y \
 emacs \
 git \
 sudo \
 python3 \
 unzip \
 wget \
 # EOL

setup: /etc/os-release
	@echo "# Please install tools, On debian: make setup/debian"
	emacs --version
	emacs \
 --no-init-file  \
 --user="${USER}" \
 --batch \
 --eval="(require 'package)" \
 --eval="(add-to-list 'package-archives \
  '(\"melpa\" . \"https://melpa.org/packages/\"))" \
 --eval='(setq gnutls-algorithm-priority "NORMAL:-VERS-TLS1.3")' \
 --eval="(package-show-package-list)" \
 --eval="(package-refresh-contents)" \
 --eval="(package-list-packages)" \
 --eval="(package-install 'org)" \
 --eval="(package-install 'htmlize)" \
 --eval="(package-install 'ox-reveal)" \
 # EOL

%.html: %.org Makefile
	cd ${<D} \
&& \
 emacs \
 --no-init-file \
 --user="${USER}" \
 --batch \
 --eval="(require 'org)" \
 --eval="(require 'ox-reveal)" \
 --find-file="${<F}" \
 --funcall="org-reveal-export-to-html" \
 # EOL

html: ${target}.html
	ls $<

all/%: ${srcs}
	for src in $^ ; do \
    target=$$(echo "$${src}" | sed -e 's|\.org$$||g') ; \
    make target="$${target}" "${@F}" \
    || exit $$? ; \
  done

run:
	python3 -m http.server ${PORT}

${deploy_dir}:
	install -d $@

deploy-files: all ${deploy_dir}
	find . -type d -iname ".git" -prune -false -o -type f \
	| while read file ; do \
	  dirname=$$(dirname $${file}) ; \
	  install -d ${deploy_dir}/$${dirname} ; \
	  install $${file} ${deploy_dir}/$${dirname}/ ; \
	done
	find ${deploy_dir} -type f

${reveal_dir}:
	@mkdir -p ${@D}
	wget -O- ${reveal_zip_url} > reveal.js.zip
	unzip reveal.js.zip
	mv reveal.js-master ${@}
	@rm -f reveal.js.zip

output:
	-git commit -sam "WIP: $@: About to generate ${target}"
	git checkout ${output_branch} \
  || git checkout -b ${output_branch} master
	make html
	git add -f ${target}.html
	-git commit -am "WIP: $@: Generated html ${target}"
	git checkout master

upload:
	git checkout master
	-git branch -D ${output_branch}
	 git checkout -b ${output_branch}
	-git commit -sam "WIP: About to download"
	make download
	git add -f "${reveal_dir}"
	-git commit -sam "WIP: Add ${reveal_dir}"
	${MAKE} all/output
	git checkout ${output_branch}
	echo "# About to push to origin in 5 secs ?"
	sleep 5 ; git push -f origin HEAD:gh-pages
	git checkout master

%.lst: %.org Makefile
	echo "" > "$@"
	-grep -o -e 'https\?://[^]"]*' -- "$<" \
 | grep -E ".**\.(gif|png|svg|jpg|jpeg|webm|mp4)"\
 | sort -u >> "$@.tmp"
	mv "$@.tmp" "$@"


%/curl:
	@mkdir -p http https
	@ln -fs http http:
	@ln -fs https https:
	ls "${@D}" > /dev/null 2>&1 \
 || curl --create-dirs -o "./${@D}" -- "${@D}"
	find . -iname "*#*" | while read file; do \
    basename=$$(basename -- "$${file}"); \
    dirname=$$(dirname -- "$${file}"); \
    dstname=$$(echo "$${basename}" | sed -e 's|#.|%23.|g'); \
    ln -fs "$${basename}" "$${dirname}/$${dstname}"; \
    dstname=$$(echo "$${basename}" | sed -e 's|#.||g'); \
    ln -fs "$${basename}" "$${dirname}/$${dstname}"; \
  done


.PHONY: cache
cache: ${target}.lst Makefile
	@mkdir -p "${<D}/${cache_dir}"
	cd "${<D}/${cache_dir}" && \
  cat "${CURDIR}/$<" | while read url ; do \
    ${make} $${url}/curl || exit $$? ; \
  done


${target}._cache.org: ${target}.lst ${target}.org cache reveal.js
	sed -e 's|^#+REVEAL_ROOT:.*|#+REVEAL_ROOT: ${CURDIR}/reveal.js|g' \
  < ${target}.org > $@.tmp
	sort -u $< | while read url; do \
    sed -e "s|$${url}|${cache_dir}/$${url}|g" \
      -e "s|${cache_dir}/http://|${cache_dir}/http/|g" \
      -e "s|${cache_dir}/https://|${cache_dir}/https/|g" \
      -i "${@}.tmp" ; \
  done
	mv "${@}.tmp" "$@"

html-cache: ${target}.org ${target}._cache.org
	make html target="${target}._cache"
	sed -e "s|#./|/./|g" -i "${target}._cache.html"

offline: all/cache all/html-cache
	sync

offline/start: offline
	${MAKE} ${@F} target="${target}._cache"

commit/offline:
	-git branch -D ${@F}/master
	git checkout -b ${@F}/master
	${MAKE} download
	-git add -f .
	-git commit -am "$@: Cache downloaded files"
	${MAKE} cache
	-git add -f .
	-git commit -am "$@: Cache downloaded files, see lst file for sources"
	${MAKE} ${@F}
	-git add -f .
	-git commit -am "$@: Render cached files"

firefox/start:
	${@D} -width ${width} -height ${height} ${url}/${target}.html


docker_workdir?=/usr/local/opt/${project}/src/${project}
docker_tmp=${docker_workdir}/tmp

docker/build: ./Dockerfile cleanall
	-docker rm ${project}
	docker build -f $< -t ${project} .

docker/run/%: ./Dockerfile
	mkdir -p tmp
	docker run \
	  -v ${CURDIR}/tmp:${docker_tmp} ${project}:latest \
	  ${@F}

docker/deploy: docker/build docker/run/deploy-files
	cp -rfv ${deploy_dir}/* ./
	@date -u

docker: docker-compose.yml
	docker-compose up --build
	@date -u

