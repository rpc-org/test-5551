/**
 * @name Checkout of untrusted code in trusted context
 * @description Workflows triggered on `pull_request_target` have read/write access to the base repository and access to secrets.
 *              By explicitly checking out and running the build script from a fork the untrusted code is running in an environment
 *              that is able to push to the base repository and to access secrets.
 * @kind problem
 * @problem.severity warning
 * @precision low
 * @id js/actions/pull-request-target
 * @tags actions
 *       security
 *       external/cwe/cwe-094
 */

import javascript
import experimental.semmle.javascript.Actions

/**
 * Action step that doesn't contain `actor` or `label` check in `if:` or
 * the check requires manual analysis.
 */
class ProbableStep extends Actions::Step {
  // some simplistic checks to eleminate likely false positives:
  ProbableStep() {
    // no if at all
    not exists(this.getIf().getValue())
    or
    // needs manual analysis if there is OR
    this.getIf().getValue().matches("%||%")
    or
    // labels can be assigned by owners only
    not exists(
      this.getIf()
          .getValue()
          .regexpFind("\\bcontains\\s*\\(\\s*github\\s*\\.\\s*event\\s*\\.\\s*(?:issue|pull_request)\\s*\\.\\s*labels\\b",
            _, _)
    ) and
    not exists(
      this.getIf()
          .getValue()
          .regexpFind("\\bgithub\\s*\\.\\s*event\\s*\\.\\s*label\\s*\\.\\s*name\\s*==", _, _)
    ) and
    // actor check means only the user is able to run it
    not exists(this.getIf().getValue().regexpFind("\\bgithub\\s*\\.\\s*actor\\s*==", _, _))
  }
}

/**
 * Action job that doesn't contain `actor` or `label` check in `if:` or
 * the check requires manual analysis.
 */
class ProbableJob extends Actions::Job {
  // some simplistic checks to eleminate likely false positives:
  ProbableJob() {
    // no if at all
    not exists(this.getIf().getValue())
    or
    // needs manual analysis if there is OR
    this.getIf().getValue().matches("%||%")
    or
    // labels can be assigned by owners only
    not exists(
      this.getIf()
          .getValue()
          .regexpFind("\\bcontains\\s*\\(\\s*github\\s*\\.\\s*event\\s*\\.\\s*(?:issue|pull_request)\\s*\\.\\s*labels\\b",
            _, _)
    ) and
    not exists(
      this.getIf()
          .getValue()
          .regexpFind("\\bgithub\\s*\\.\\s*event\\s*\\.\\s*label\\s*\\.\\s*name\\s*==", _, _)
    ) and
    // actor check means only the user is able to run it
    not exists(this.getIf().getValue().regexpFind("\\bgithub\\s*\\.\\s*actor\\s*==", _, _))
  }
}

/**
 * Workflow triggered on `pull_request_target` trigger that doesn't only run
 * for the `labeled` activity
 */
class ProbablePullRequestTarget extends Actions::On, Actions::MappingOrSequenceOrScalar {
  ProbablePullRequestTarget() {
    exists(Actions::MappingOrSequenceOrScalar prt |
      // The `on:` is triggered on `pull_request_target`
      this.getNode("pull_request_target") = prt and
      // Doesn't have the `types` filter which is just [labeled]
      not exists(Actions::MappingOrSequenceOrScalar types |
        types = prt.getNode("types") and
        forall(YAMLString type | type = types.getAChild() | type.getValue() = "labeled")
      )
    )
  }
}

from
  Actions::Ref ref, Actions::Uses uses, Actions::Step step, Actions::Job job,
  ProbablePullRequestTarget pullRequestTarget
where
  pullRequestTarget.getWorkflow() = job.getWorkflow() and
  uses.getStep() = step and
  ref.getWith().getStep() = step and
  step.getJob() = job and
  uses.getGitHubRepository() = "actions/checkout" and
  (
    ref.getValue().matches("%github.event.pull_request.head.ref%") or
    ref.getValue().matches("%github.event.pull_request.head.sha%") or
    ref.getValue().matches("%github.event.pull_request.number%") or
    ref.getValue().matches("%github.event.number%") or
    ref.getValue().matches("%github.head_ref%")
  ) and
  step instanceof ProbableStep and
  job instanceof ProbableJob
select step, "Potential unsafe checkout of untrusted pull request on `pull_request_target`"
