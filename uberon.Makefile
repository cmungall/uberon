
TEMPLATESDIR=templates

TEMPLATES=$(patsubst %.tsv, $(TEMPLATESDIR)/%.owl, $(notdir $(wildcard $(TEMPLATESDIR)/*.tsv)))

.PHONY: templates
templates: $(TEMPLATES)

$(TEMPLATESDIR)/%.owl: $(TEMPLATESDIR)/%.tsv $(SRC)
	$(ROBOT) -vvv merge -i $(SRC) template --template $< --prefix "EFO: http://www.ebi.ac.uk/efo/EFO_" --output $@ && \
	$(ROBOT) -vvv annotate --input $@ --ontology-iri $(ONTBASE)/components/$*.owl -o $@


TMPDIR=tmp/
REPORTSDIR=reports/
SRC=uberon_edit.obo

dirs:
	mkdir -p $(TMPDIR)
	mkdir -p $(REPORTSDIR)

tmp/$(ONT)-quick.obo: | dirs
	$(ROBOT) merge -i $(SRC) reason -o $@.owl && mv $@.owl $@

tmp/$(ONT)-main.obo: | dirs
	git show master:$(SRC) > $@
	$(ROBOT) merge -i $@ reason -o $@.owl && mv $@.owl $@

reports/robot_main_diff.md: tmp/$(ONT)-quick.obo tmp/$(ONT)-main.obo
	$(ROBOT) diff --left tmp/$(ONT)-main.obo --right tmp/$(ONT)-quick.obo -f markdown -o $@

.PHONY: feature_diff
feature_diff: reports/robot_main_diff.md
