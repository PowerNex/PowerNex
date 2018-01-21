pipeline {
	agent { docker "wild/powernex-env" }
	stages {
		stage('build') {
			steps {
				script {
					if (env.JOB_NAME.endsWith("_pull-requests"))
						setGitHubPullRequestStatus state: 'PENDING', context: "${env.JOB_NAME}", message: "Building powernex"
				}
				ansiColor('xterm') {
					sh '''
					rm -rf cc || true
					mkdir build
					ln -s /usr build/cc
					mkdir HOME || true; export HOME="$(pwd)/HOME"
					source ./env.sh
					c
					rm -rf build.ninja compile_commands.json rules.ninja || true
					touch ./reggaefile.d
					v
					'''
        }
			}
		}

		stage('archive') {
			steps {
				script {
					if (env.JOB_NAME.endsWith("_pull-requests"))
						setGitHubPullRequestStatus state: 'PENDING', context: "${env.JOB_NAME}", message: "Archiving powernex"
				}
				archiveArtifacts artifacts: 'powernex.iso', fingerprint: true
			}
		}
	}

  post {
    success {
			script {
				if (env.JOB_NAME.endsWith("_pull-requests"))
					setGitHubPullRequestStatus state: 'SUCCESS', context: "${env.JOB_NAME}", message: "powernex building successed"
			}
    }
		failure {
			script {
				if (env.JOB_NAME.endsWith("_pull-requests"))
					setGitHubPullRequestStatus state: 'FAILURE', context: "${env.JOB_NAME}", message: "powernex building failed"
			}
		}
  }
}
