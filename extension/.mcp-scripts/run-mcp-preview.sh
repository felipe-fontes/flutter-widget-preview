#!/bin/bash
cd "/Users/felipesantos/code/dartvm-preview/fontes_widget_viewer/extension/packages/mcp_preview"
exec dart run bin/mcp_preview.dart --fonts-path="/Users/felipesantos/code/dartvm-preview/fontes_widget_viewer/extension/fonts" "$@"
