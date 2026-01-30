import * as vscode from 'vscode';

export class CodeLensProvider implements vscode.CodeLensProvider {
    private testWidgetsPattern = /testWidgets\s*\(\s*['"]([^'"]+)['"]/g;

    provideCodeLenses(
        document: vscode.TextDocument,
        _token: vscode.CancellationToken
    ): vscode.CodeLens[] {
        const codeLenses: vscode.CodeLens[] = [];
        const text = document.getText();

        let match: RegExpExecArray | null;
        while ((match = this.testWidgetsPattern.exec(text)) !== null) {
            const testName = match[1];
            const position = document.positionAt(match.index);
            const range = new vscode.Range(position, position);

            codeLenses.push(
                new vscode.CodeLens(range, {
                    title: '▶ Preview',
                    command: 'flutterPreview.previewTest',
                    arguments: [
                        {
                            file: document.uri.fsPath,
                            testName: testName,
                            line: position.line + 1,
                        },
                    ],
                })
            );
        }

        // Reset regex state
        this.testWidgetsPattern.lastIndex = 0;

        return codeLenses;
    }
}
