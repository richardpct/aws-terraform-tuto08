## Purpose

This tutorial takes up the previous one
[aws-terraform-tuto07](https://richardpct.github.io/post/2021/04/17/aws-with-terraform-tutorial-07/)
by adding autoscaling policy in order to scale up our web server according to a
metric that you chose, for our example I chose to add a web server if the CPU
Load is higher than a threshold that I have defined.

The following figure depicts the infrastructure you will build:

<img src="https://raw.githubusercontent.com/richardpct/images/master/aws-tuto-08/image01.png">

The source code can be found [here](https://github.com/richardpct/aws-terraform-tuto08).

## Configuring the autoscaling policy

#### modules/web/main.tf

I only show the relevant excerpt on how to configure the autoscaling policy:

```
resource "aws_autoscaling_group" "web" {
  name                = "asg_web-${var.env}"
  vpc_zone_identifier = data.terraform_remote_state.network.outputs.subnet_private_web_id[*]
  target_group_arns   = [data.terraform_remote_state.network.outputs.alb_target_group_web_arn]
  health_check_type   = "ELB"
  min_size            = 2
  max_size            = 3

  launch_template {
    id = aws_launch_template.web.id
  }

  tag {
    key                 = "Name"
    value               = "web-${var.env}"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "web" {
  name                   = "autoscaling_policy_web-${var.env}"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.web.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 40.0
  }
}
```

`min_size = 2` intends to have at least 2 web servers up and running, and
`max_size = 3` intends to have at maximum 3 web servers in any case.<br />
`predefined_metric_type = "ASGAverageCPUUtilization"` intends to use the
CPU Load Metric for scaling the web servers.<br />
`target_value = 40.0` intends to scale up when the average CPU Load of all our
web server is higher than 40% and when the average is lower than 40% the
autoscaling will scale down.

## Deploying the infrastructure

Prepare your variables at ~/terraform/aws-terraform-tuto08/terraform_vars_dev_secrets:

```
export TF_VAR_aws_profile="dev"
export TF_VAR_region="eu-west-3"
export TF_VAR_bucket="XXX-tofu-state"
export TF_VAR_key_network="tuto-08/dev/network/terraform.tfstate"
export TF_VAR_key_bastion="tuto-08/dev/bastion/terraform.tfstate"
export TF_VAR_key_database="tuto-08/dev/database/terraform.tfstate"
export TF_VAR_key_web="tuto-08/dev/web/terraform.tfstate"
export TF_VAR_ssh_public_key="ssh-ed25519 AAAAXXX"
MY_IP=$(curl -s ifconfig.co/)
export TF_VAR_my_ip_address="$MY_IP/32"
```

Building:

    $ cd envs/dev/01-network
    $ make apply
    $ cd ../02-bastion
    $ make apply
    $ cd ../03-database
    $ make apply
    $ cd ../04-web
    $ make apply

## Testing your infrastructure

When your infrastructure is built, get the DNS name of your Load Balancer by
performing the following command:

    $ aws --profile dev elbv2 describe-load-balancers --names alb-web-dev \
        --query 'LoadBalancers[*].DNSName' \
        --output text

Then issue the following command several times for increasing the counter:

    $ curl http://DNS_load_balancer/cgi-bin/hello.py

It should return the count of requests you have performed, and you notice that
you see 2 differents instance-id.

## Testing the automation of autoscaling

Chose one of the 2 running instances and connect to it, then install the stress
package in order to burn the CPU:

    $ ssh -J ec2-user@IP_public_bastion ec2-user@IP_private_instance_web
    $ sudo su -
    # yum install stress
    # stress --cpu 1

Wait for a while, then a third web server will be created and the Load Balancer
will register it, you now have three healthy instances.<br />
If you make some requests to the service again, you will notice that the three
servers will serve your requests by displaying 3 differents instance-id:

    $ curl http://DNS_load_balancer/cgi-bin/hello.py

For testing the scale down when there is no longer high load, just stop the
stress process by pressing `CTRL-C` in your terminal, then a web server will be
terminated and you have now 2 web servers up and running.

## Destroying your infrastructure

After finishing your test, destroy your infrastructure:

    $ cd envs/dev/04-web
    $ make destroy
    $ cd ../03-database
    $ make destroy
    $ cd ../02-bastion
    $ make destroy
    $ cd ../01-network
    $ make destroy

## Summary

I showed you how to configure an infrastructure with auto scaling.<br />
In the next chapter, I will show you how to build a real infrastructure by
deploying Gitlab, and we will leverage and apply all the lessons we have
learned for now.
