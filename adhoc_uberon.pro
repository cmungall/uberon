
:- use_module(bio(bioprolog_util)).
:- use_module(bio(ontol_db)).
:- use_module(bio(metadata_db)).
:- use_module(bio(metadata_nlp)).
:- use_module(bio(ontol_reasoner)).
:- use_module(bio(mode)).
:- use_module(bio(dbmeta)).
:- use_module(bio(graph)).
:- use_module(library(porter_stem),[]).

t:-
        forall(restriction(C,broader,P),
               (   inf(C,P,Goal),
                   write('ontol_db:'),
                   writeq(Goal),
                   write('.'),nl)).

inf(C,P,Goal):-
        Goal=subclass_i(C,P),
        Goal,
        !.
inf(C,P,Goal):-
        Goal=restriction_i(C,part_of,P),
        Goal,
        !.
inf(C,P,Goal):-
        Goal=other(C,P),
        Goal,
        !.
inf(C,P,no(C,P)).


% convert MIAA broader relations to is_a; only if there is a subclass chain in ont
ontol_db:subclass(C,P):-
        belongs(C,'http://www.xspan.org/obo.owl#'),
        restriction(C,broader,P),
        xref(C,CX),
        subclassT(CX,PX),
        xref(P,PX).

% convert MIAA broader relations to is_a; only if there is a relation chain in ont
ontol_db:restriction(C,part_of,P):-
        belongs(C,'http://www.xspan.org/obo.owl#'),
        restriction(C,broader,P),
        xref(C,CX),
        parent_overT(part_of,CX,PX),
        xref(P,PX).

ontol_db:restriction(C,other,P):-
        belongs(C,'http://www.xspan.org/obo.owl#'),
        restriction(C,broader,P),
        xref(C,CX),
        parentRT(part_of,CX,PX),
        xref(P,PX).

xref(C,X):-
        entity_alternate_identifier(C,X).


wpxref_url(X,Page,URL) :-
	atom_concat('Wikipedia:',Page,X),
	atom_concat('http://dbpedia.org/resource/',Page,URL).

%% class_page_canonical(?C,?Page,?CanonicalTo)
% Page is e.g. Amnion
% CanonicalURL is the canonical URL
class_page_canonical(C,Page,CanonicalURL):-
	def_xref(C,X),
	wpxref_url(X,Page,URL),
	dbpedia_canonical(URL,CanonicalURL).

class_newdef(C,Def) :-
	def(C,'.'),
	class_page_canonical(C,_,URL),
	rdf(URL,'http://dbpedia.org/property/abstract',literal(lang(en,Def1))),
	atom_concat(Def1,' [WP,unvetted].',Def).

dbpedia_devfrom(Post,Pre) :-
	class_page_canonical(Pre,_,XPre),
	rdf(XPre,'http://dbpedia.org/property/givesriseto',XPost),
	class_page_canonical(Post,_,XPost),
	\+ restriction(Post,develops_from,Pre),
	\+ restriction(Pre,develops_into,Post).

dbpedia_syn(C,Syn) :-
	class_page_canonical(C,_,Canonical),
	rdf(SynURL,'http://dbpedia.org/property/redirect',Canonical),
	atom_concat('http://dbpedia.org/resource/',SynPage,SynURL),
	concat_atom(Toks,'_',SynPage),
	concat_atom(Toks,' ',SynUC),
	downcase_atom(SynUC,Syn),
	term_token_stemmed(Syn,SynStemmed,true),
	\+entity_label_token_stemmed(_,_,SynStemmed,true).

dbpedia(Page) :-
	setof(Page,T^rdf(Page,'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',T),Pages),
	member(Page,Pages).

dbpedia_new(URL) :-
	dbpedia(URL),
	atom_concat('http://dbpedia.org/resource/',_Page,URL),
	\+class_page_canonical(_,_,URL).



	
	

dbpedia_canonical(InURL,CanonicalURL) :-
	rdf(InURL,'http://dbpedia.org/property/redirect',CanonicalURL).
dbpedia_canonical(InURL,InURL) :-
	\+ \+ rdf(InURL,'http://www.w3.org/1999/02/22-rdf-syntax-ns#type',_).


idspace_map('TAO',_) :- fail,!.
idspace_map('MIAA',_) :- fail,!.
idspace_map('ZFA','ZFA/ZFS') :- !.
idspace_map('ZFS','ZFA/ZFS') :- !.
idspace_map('BILA','BILA/BILS') :- !.
idspace_map('BILS','BILA/BILS') :- !.
idspace_map(X,X).



uberon_xref_in(E,X,S) :-
	entity_xref(E,X),
	id_idspace(X,S1),
	idspace_map(S1,S).

uberon_xref_count(S,Num) :-
	aggregate(count,
		  X,
		  E^uberon_xref_in(E,X,S),
		  Num),
	Num > 32.

uberon_compare_sets_by_relT(X1,X2,Rel,Diff) :-
	findall(C,parent_overT(Rel,C,X1),Set1),
	findall(C,parent_overT(Rel,C,X2),Set2),
	debug(uberon,'comparing: ~w -VS- ~w',[Set1,Set2]),
	uberon_compare_sets(Set1,Set2,Diff).
uberon_compare_sets_by_rel(X1,X2,Rel,Diff) :-
	findall(C,parent(C,Rel,X1),Set1),
	findall(C,parent(C,Rel,X2),Set2),
	debug(uberon,'comparing: ~w -VS- ~w',[Set1,Set2]),
	uberon_compare_sets(Set1,Set2,Diff).
uberon_compare_sets_by_query(T1,Q1,T2,Q2,Diff) :-
	findall(T1,Q1,Set1),
	findall(T2,Q2,Set2),
	uberon_compare_sets(Set1,Set2,Diff).

uberon_compare_sets(Set1,Set2,Diff) :-
	member(X1,Set1),
	entity_xref(U,X1),
	uberon_in_set(U,Set2,Diff).
uberon_compare_sets(Set1,Set2,Diff) :-
	member(X2,Set2),
	entity_xref(U,X2),
	uberon_in_set(U,Set1,Diff).

uberon_in_set(U,Set2,match-U) :-
	entity_xref(U,X2),
	member(X2,Set2),
	!.
uberon_in_set(U,Set2,diff-U) :-
	entity_xref(U,X2),
	member(Random,Set2),
	id_idspace(Random,S),
	id_idspace(X2,S),
	!.
uberon_in_set(U,_,no_xref-U).

	

	