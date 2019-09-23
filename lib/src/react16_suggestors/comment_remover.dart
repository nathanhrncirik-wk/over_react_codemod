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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/react16_suggestors/react16_utilities.dart';

/// Suggestor that removes a specific comment from files.
class CommentRemover extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {

  /// The list of comments to be removed if found.
  final List<String> commentsToRemove;

  /// The list of comments that should cause the codemod to not yield patches
  /// in this file.
  final List<String> shortCircuitComments;

  CommentRemover(this.commentsToRemove, [this.shortCircuitComments = const []]);

  @override
  visitClassDeclaration(ClassDeclaration node) {
    super.visitClassDeclaration(node);
    for (Token comment in allComments(node.root.beginToken)) {
      if (comment != null) {
        final commentValue = comment.toString().toLowerCase();

        if (shortCircuitComments.contains(commentValue)) return;

        for (String commentToRemove in commentsToRemove) {
          if (commentValue.contains(RegExp(commentToRemove.toLowerCase()))) {
            yieldPatch(comment.offset, comment.end, '');
          }
        }
      }
    }
  }
}
