// Copyright 2019 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:analyzer/analyzer.dart';
import 'package:codemod/codemod.dart';

import '../constants.dart';

/// Suggestor that renames `componentWillUnmount` to `init` and removes
/// super calls to be compatible with UiComponent2.
class ComponentWillMountMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  ComponentWillMountMigrator();

  @override
  visitMethodDeclaration(MethodDeclaration node) {
    super.visitMethodDeclaration(node);
    ClassDeclaration containingClass = node.parent;
    if (containingClass.metadata
        .any((m) => overReact16AnnotationNames.contains(m.name.name))) {
      // Update method name.
      if (node.name.toSource() == 'componentWillMount') {
        yieldPatch(
          node.name.offset,
          node.name.end,
          'init',
        );

        // Remove super call.
        if (node.body is BlockFunctionBody) {
          NodeList statementList =
              (node.body as BlockFunctionBody).block.statements;
          statementList.forEach((statement) {
            if (statement.toString().startsWith('super.componentWillMount()')) {
              yieldPatch(
                statement.offset,
                statement.end,
                '',
              );
            }
          });
        }
      }
    }
  }
}
