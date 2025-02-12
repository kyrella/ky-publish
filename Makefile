SRC = ky-publish.el

PKG_NAME = ky-publish
PKG_FILE = ${PKG_NAME}-pkg.el
PKG_VERSION = 0.1.3
PKG_FULL_NAME = ${PKG_NAME}-${PKG_VERSION}

package: ${PKG_NAME}-${PKG_VERSION}.tar

${PKG_FULL_NAME}.tar: ${SRC} ${PKG_FILE}
	mkdir ${PKG_FULL_NAME}
	cp $^ ${PKG_FULL_NAME}
	tar -cf $@ ${PKG_FULL_NAME}
	rm -rf ${PKG_FULL_NAME}

clean:
	rm -f *.tar
