// Copyright 2020 Workiva Inc.
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

import 'dart:io';

import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/annotations_remover.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_utilities.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/props_meta_migrator.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/simple_props_and_state_class_migrator.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/advanced_props_and_state_class_migrator.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/props_mixins_migrator.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/stubbed_props_and_state_class_remover.dart';
import 'package:over_react_codemod/src/ignoreable.dart';

const _convertedClassesWithExternalSuperclassFlag =
    '--convert-classes-with-external-superclasses';
const _treatAllComponentsAsPrivateFlag = '--treat-all-components-as-private';
const _changesRequiredOutput = '''
  To update your code, run the following commands in your repository:
  pub global activate over_react_codemod
  pub global run over_react_codemod:boilerplate_upgrade
  pub run dart_dev format (if you format this repository).
  Then, review the the changes, address any FIXMEs, and commit.
''';

Future<void> main(List<String> args) async {
  final convertClassesWithExternalSuperclass =
      args.contains(_convertedClassesWithExternalSuperclassFlag);
  args.removeWhere((arg) => arg == _convertedClassesWithExternalSuperclassFlag);

  final shouldTreatAllComponentsAsPrivate =
      args.contains(_treatAllComponentsAsPrivateFlag);
  args.removeWhere((arg) => arg == _treatAllComponentsAsPrivateFlag);

  final query = FileQuery.dir(
    pathFilter: (path) {
      return isDartFile(path) && !isGeneratedDartFile(path);
    },
    recursive: true,
  );

  final classToMixinConverter = ClassToMixinConverter();

  final semverHelper = await getSemverHelper('semver_report.json',
      shouldTreatAllComponentsAsPrivate: shouldTreatAllComponentsAsPrivate);

  // General plan:
  //  - Things that need to be accomplished (very simplified)
  //    1. Make props / state class a mixin
  //    2. Remove stub props / state classes
  //    3. Remove annotations
  //
  //  - Before any changes occur (short circuit conditions):
  //    1. Check that the component is `component2`
  //    2. Check whether the props class is a public API
  //      i. If this is unavailable, check the flag
  //
  //  - Suggestors:
  //    1. Handle basic use cases
  //    2. Handle advanced cases
  //    3. Remove stubbed meta class
  //    4. Remove annotations
  //    5. Transition `PropsMixins`
  //
  //  - Common Utilities
  //    - Detect Component2 (for short circuit condition 1)
  //      - use `isAssociatedWithComponent2`
  //    - Detect if the class is "simple".
  //      - If false, short circuit suggestor 1
  //      - If true, short circuit suggestor 2
  //      - use `isSimplePropsOrStateClass`
  //    - Switch a props / state class to a `mixin`
  //      - Both the simple and advanced migrators likely need to switch a class
  //        to a mixin (the advanced case can then just add a new line)
  //      - use `migrateClassToMixin`
  //    -? Detect if the file _will_ be updated
  //      - NOTE: not created yet
  //      - Can we rely on timing of suggestors? As in, if a suggestor runs after a different one, will its changes be in place?
  //          - IIRC, no?
  //      - If this is needed, it can be used for suggestors 3 and 4
  //
  //
  exitCode = runInteractiveCodemodSequence(
    query,
    <Suggestor>[
      // We need this to run first so that the AdvancedPropsAndStateClassMigrator
      // can check for duplicate mixin names before creating one.
      PropsMixinMigrator(classToMixinConverter, semverHelper),
      SimplePropsAndStateClassMigrator(classToMixinConverter, semverHelper),
      AdvancedPropsAndStateClassMigrator(
        classToMixinConverter,
        semverHelper,
        // When we visit these nodes the first time around, we can't assume that
        // they come from an external lib just because they do not
        // appear within `ClassToMixinConverter.visitedClassNames`
        treatUnvisitedClassesAsExternal: false,
      ),
      // NOTE: The convertClassesWithExternalSuperclass is intentionally only set
      // based on the CLI flag value the second time around.
      AdvancedPropsAndStateClassMigrator(
        classToMixinConverter,
        semverHelper,
        convertClassesWithExternalSuperclass:
            convertClassesWithExternalSuperclass,
        // Now that we have visited all of the nodes once, we can assume that
        // they come from an external lib if they do not
        // appear within `ClassToMixinConverter.visitedClassNames`
        treatUnvisitedClassesAsExternal: true,
      ),
      PropsMetaMigrator(classToMixinConverter),
      // Run this last so that the decision about whether to migrate the class is based on
      // the final migrated / un-migrated state of the class after the simple/advanced class
      // migrators have finished, but before the annotations are removed.
      StubbedPropsAndStateClassRemover(classToMixinConverter),
      AnnotationsRemover(classToMixinConverter),
    ].map((s) => Ignoreable(s)),
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );
}
