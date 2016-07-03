target=index
NAME?=$(shell grep 'TITLE:' ${target}.org | cut -d':' -f2)

reveal_url?=https://github.com/hakimel/reveal.js/
reveal_zip_url?=https://github.com/hakimel/reveal.js/archive/master.zip
web_url?=https://${USER}.github.io/${USER}-example/
licence_url?=https://licensedb.org/id/CC-BY-SA-4.0.txt

all: LICENSE url.lst ${target}.html

%.org: reveal.js Makefile

%.html: %.org Makefile
	NAME="${NAME}" emacs --batch\
 -u ${USER} \
  --eval '(load user-init-file)' \
  $< \
  -f org-reveal-export-to-html

run: ${target}.html
	x-www-browser "$<"
help:
	@echo "https://github.com/yjwen/org-reveal/issues/171"

clean:
	rm -rfv *~ tmp


setup:
	sudo apt-get install wget emacs sudo unzip git

config: reveal.js
	rm -f resources.lst *~

tmp/reveal.js:
	git submodule update \
	|| git submodule add ${reveal_url} --depth 1 -b master

reveal.js:
	wget -O- ${reveal_zip_url} > tmp.zip && unzip tmp.zip \
 && mv reveal.js-master reveal.js

deploy: all reveal.js
	-git add .
	-git commit -sam 'WIP'
	git push origin -f  HEAD:gh-pages

test:
	x-www-browser ${web_url}

LICENSE:
	@echo "Update ${CURDIR}/Makefile to setup licence"
	@echo "Fetching default one at:"
	@echo "URL: ${licence_url}"
	wget -O $@ "${licence_url}"


url.lst: ${target}.org online
	echo "" > "$@"
	-grep -o -e 'http[^]]*' $< | grep -v '*/' | grep .png >> $@
	-grep -o -e 'http[^]]*' $< | grep -v '*/' | grep .svg >> $@
	sort "$@" | uniq > "$@.tmp" && mv "$@.tmp" "$@"

cache?=.
offline: ${target}.org Makefile download
	-@ln -fs .  http:
	-@ln -fs .  https:
	-@ln -fs .  http
	-@ln -fs .  https
	-sed -e "s|http://|${cache}/http/|g" -i $<

online:  ${target}.org Makefile
	-sed -e "s|${cache}/http|http://|g" -i $<


download: url.lst Makefile
	wget -p -i ${CURDIR}/$<

