# == Defined Type: ubuntu_redis::sentinel
# Function to configure an redis sentinel server.
#
# === Parameters
#
# [*sentinel_name*]
#   Name of Sentinel instance. Default: call name of the function.
# [*sentinel_ip*]
#   Listen IP.
# [*sentinel_port*]
#   Listen port of Redis. Default: 26379
# [*sentinel_log_dir*]
#   Path for log. Full log path is <sentinel_log_dir>/redis-sentinel_<redis_name>.log. Default: /var/log
# [*sentinel_pid_dir*]
#   Path for pid file. Full pid path is <sentinel_pid_dir>/redis-sentinel_<redis_name>.pid. Default: /var/run
# [*monitors*]
#   Default is
#
# [*protected_mode*]
#   If no password and/or no bind address is set, sentinel defaults to being reachable only
#   on the loopback interface. Turn this behaviour off by setting protected mode to 'no'.
#
# {
#   'mymaster' => {
#     master_host             => '127.0.0.1',
#     master_port             => 6379,
#     quorum                  => 2,
#     down_after_milliseconds => 30000,
#     parallel-syncs          => 1,
#     failover_timeout        => 180000,
#     ## optional
#     auth-pass => 'secret_Password',
#     notification-script => '/var/redis/notify.sh',
#     client-reconfig-script => '/var/redis/reconfig.sh'
#   },
# }
#   All information for one or more sentinel monitors in a Hashmap.
# [*running*]
#   Configure if Sentinel should be running or not. Default: true
# [*enabled*]
#   Configure if Sentinel is started at boot. Default: true
# [*sentinel_run_dir*]
#
#   Default: `/var/run/redis`
#
#   Since sentinels automatically rewrite their config since version 2.8 the puppet managed config will be copied
#   to this directory and than sentinel will start with this copy.
# [*manage_logrotate*]
#   Configure logrotate rules for redis sentinel. Default: true
define ubuntu_redis::sentinel (
  $ensure           = 'present',
  $sentinel_name    = $name,
  $sentinel_ip      = undef,
  $sentinel_port    = 26379,
  $sentinel_log_dir = '/var/log',
  $sentinel_pid_dir = '/var/run',
  $sentinel_run_dir = '/var/run/redis',
  $protected_mode   = undef,
  $monitors         = {
    'mymaster' => {
      master_host             => '127.0.0.1',
      master_port             => 6379,
      quorum                  => 2,
      down_after_milliseconds => 30000,
      parallel-syncs          => 1,
      failover_timeout        => 180000,
# optional
# auth-pass => 'secret_Password',
# notification-script => '/var/redis/notify.sh',
# client-reconfig-script => '/var/redis/reconfig.sh',
    }
  },
  $running          = true,
  $enabled          = true,
  $manage_logrotate = true,
  $sentinel_user = 'redis',
  $sentinel_group = 'redis',
) {

  # validate parameters
  validate_absolute_path($sentinel_log_dir)
  validate_absolute_path($sentinel_pid_dir)
  validate_absolute_path($sentinel_run_dir)
  validate_hash($monitors)
  validate_bool($running)
  validate_bool($enabled)
  validate_bool($manage_logrotate)

  if $protected_mode {
    validate_re($protected_mode,['^no$', '^yes$'])
  }

  # redis conf file
  $conf_file_name = "redis-sentinel_${sentinel_name}.conf"
  $conf_file = "/etc/redis/${conf_file_name}"
  file { $conf_file:
      ensure  => file,
      content => template('redis/etc/sentinel.conf.erb'),
  }

  $service_file = "/usr/lib/systemd/system/redis-sentinel_${sentinel_name}.service"
	exec { "systemd_service_sentinel_${sentinel_name}_preset":
	command     => "/bin/systemctl preset redis-sentinel_${sentinel_name}.service",
	notify      => Service["redis-sentinel_${sentinel_name}"],
	refreshonly => true,
	}

	file { $service_file:
	ensure  => file,
	mode    => '0755',
	content => template('redis/systemd/sentinel.service.erb'),
	require => File[$conf_file],
	notify  => Exec["systemd_service_sentinel_${sentinel_name}_preset"],
	}

  # manage sentinel service
  service { "redis-sentinel_${sentinel_name}":
    ensure     => $running,
    enable     => $enabled,
    hasstatus  => true,
    hasrestart => true,
    subscribe  => File[$conf_file],
  }

  if ($manage_logrotate == true){
    # install and configure logrotate
    if ! defined(Package['logrotate']) {
      package { 'logrotate': ensure => installed; }
    }

    file { "/etc/logrotate.d/redis-sentinel_${sentinel_name}":
      ensure  => file,
      content => template('redis/sentinel_logrotate.conf.erb'),
      require => [
        Package['logrotate'],
        File["/etc/redis/redis-sentinel_${sentinel_name}.conf"],
      ]
    }
  }
}
