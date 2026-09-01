# Core module

Cross-cutting infrastructure shared by feature modules: app navigation, localization, theme primitives, reusable UI, shared domain models, connectivity, persistence, and platform adapters.

Feature modules must depend on core/public APIs rather than importing another feature's private implementation.