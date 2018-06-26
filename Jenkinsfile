node {
  def tag_name = env.BRANCH_NAME.split('/').last()
  if ( tag_name == "master" ) {
    tag_name = "production"
  }
  checkout scm
  sh "docker build -t nulib/avr:${tag_name} ."
  docker.withRegistry('', 'docker-hub-credentials') {
    docker.image("nulib/avr:${tag_name}").push()
  }
  sh "docker tag \$(docker image ls -q --filter 'label=edu.northwestern.library.role=support' --filter 'label=edu.northwestern.library.app=AVR' | head -1) nulib/avr-build:${tag_name}"
  sh "docker image prune -f"
  sh "docker run -t -v /home/ec2-user/.aws:/root/.aws nulib/ebdeploy ${tag_name} avr"
}
