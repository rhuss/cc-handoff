.PHONY: validate install uninstall reinstall help

MARKETPLACE := cc-handoff-marketplace
PLUGIN := handoff@$(MARKETPLACE)

validate:
	claude plugin validate ./
	claude plugin validate ./handoff/

install:
	@claude plugin rm $(PLUGIN) 2>/dev/null || true
	@claude plugin marketplace rm $(MARKETPLACE) 2>/dev/null || true
	@claude plugin marketplace add ./ && echo "Marketplace added."
	claude plugin install $(PLUGIN)

uninstall:
	@echo "Removing plugin..."
	@claude plugin rm $(PLUGIN) 2>/dev/null || echo "Plugin not installed"
	@echo "Removing marketplace..."
	@claude plugin marketplace rm $(MARKETPLACE) 2>/dev/null || echo "Marketplace not installed"

reinstall: uninstall install

help:
	@echo "Available targets:"
	@echo "  validate   - Validate plugin manifests"
	@echo "  install    - Install or update plugin (idempotent)"
	@echo "  uninstall  - Remove plugin and marketplace"
	@echo "  reinstall  - Full reinstall (uninstall + install)"
