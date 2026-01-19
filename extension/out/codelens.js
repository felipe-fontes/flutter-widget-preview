"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.CodeLensProvider = void 0;
const vscode = __importStar(require("vscode"));
class CodeLensProvider {
    constructor() {
        this.testWidgetsPattern = /testWidgets\s*\(\s*['"]([^'"]+)['"]/g;
    }
    provideCodeLenses(document, _token) {
        const codeLenses = [];
        const text = document.getText();
        let match;
        while ((match = this.testWidgetsPattern.exec(text)) !== null) {
            const testName = match[1];
            const position = document.positionAt(match.index);
            const range = new vscode.Range(position, position);
            codeLenses.push(new vscode.CodeLens(range, {
                title: '▶ Preview',
                command: 'fontesWidgetViewer.previewTest',
                arguments: [{
                        file: document.uri.fsPath,
                        testName: testName,
                        line: position.line + 1
                    }]
            }));
        }
        this.testWidgetsPattern.lastIndex = 0;
        return codeLenses;
    }
}
exports.CodeLensProvider = CodeLensProvider;
//# sourceMappingURL=codelens.js.map