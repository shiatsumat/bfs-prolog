bfs-prolog: src/lexer.mll src/parser.mly src/syntax.ml src/main.ml
	ocamllex src/lexer.mll
	ocamlyacc src/parser.mly
	ocamlopt.opt -o bfs-prolog -I src \
		src/syntax.ml src/parser.mli src/parser.ml src/lexer.ml src/main.ml

clean:
	rm -f src/*.cmi src/*.cmx src/*.o \
		src/lexer.ml src/parser.mli src/parser.ml \
		bfs-prolog
