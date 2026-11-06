# Mermaid Diagram Gallery (`studio/diagrams/`)

This folder contains all Mermaid diagram files loaded dynamically by
**Pele Studio** (`studio/`), the test suite, and documentation tools.

## Supported File Extensions

- **`.mmd`** *(standard Mermaid CLI & GitHub Linguist extension)*
- **`.mermaid`** *(descriptive Mermaid extension)*

## Folder Structure

- `01_core/<family>/` — Core Mermaid diagram families (10 families)
- `02_extended/<family>/` — Extended & beta Mermaid diagram families (23 families)
- `03_custom/` — Drop your own `.mmd` or `.mermaid` files (or subfolders) here!

## Adding New Diagrams

1. Drop any `.mmd` or `.mermaid` file into an existing family folder or into `03_custom/`.
2. Optional: Add `%% label: My Custom Title` on the first line of the file to customize its display label.
3. Click the **Rescan Folder (`↻`)** button in the example app sidebar to load new files immediately.
