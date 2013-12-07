module Bot::Adapter::Irc::RFC2812
  def admin(server=nil)
    send "ADMIN #{server}"
  end

  def away(message=nil)
    send "AWAY #{message}"
  end

  def cnotice(nickname, channel, message)
    send "CNOTICE #{nickname} #{channel} :#{message}"
  end

  def cprivmsg(nickname, channel, message)
    send "CPRIVMSG #{nickname} #{channel} :#{message}"
  end

  def connect(server, port, remote_server=nil)
    send "CONNECT #{server} #{port} #{remote server}"
  end

  def die
    send "DIE"
  end

  def encap(source, destination, subcommand, parameters)
    send ":#{source} ENCAP #{destination} #{subcommand} #{parameters}"
  end

  def error(message)
    send "ERROR #{message}"
  end

  def help
    send "HELP"
  end

  def info(target)
    send "INFO #{target}"
  end

  def invite(nickname, channel)
    send "INVITE #{nickname} #{channel}"
  end

  def ison(nickname)
    send "ISON #{nickname}"
  end

  def join(channels, keys=[])
    channels = channels.join(',') if channels.is_a?(Array)
    send "JOIN #{channels} #{keys.join(',')}"
  end

  def kick(channel, client, message=nil)
    send "KICK #{channel} #{client} #{message}"
  end

  def kill(client, comment)
    send "KILL #{client} #{comment}"
  end

  def knock(channel, message=nil)
    send "KNOCK #{channel} #{message}"
  end

  def links
    send "LINKS"
  end

  def links(remote_server, server_mask)
    send "LINKS #{remote_server} #{server_mask}"
  end

  def list
    send "LIST"
  end

  def list(channels, server=nil)
    send "LIST #{channels} #{server}"
  end

  def lusers
    send "LUSERS"
  end

  def lusers(mask, server=nil)
    send "LUSERS #{mask} #{server}"
  end

  def mode(nickname, flags, args)
    if args.is_a?(Array)
      send "MODE #{nickname} #{flags} #{args.join(',')}"
    else
      send "MODE #{nickname} #{flags} #{args}"
    end
  end

  def motd(server=nil)
    send "MOTD #{server}"
  end

  def names
    send "NAMES"
  end

  def names(channels, server=nil)
    send "NAMES #{channels} #{server}"
  end

  def namesx
    send "PROTOCTL NAMESX"
  end

  def nick(nickname)
    send "NICK #{nickname}"
  end

  def notice(msgtarget, message)
    send "NOTICE #{msgtarget} #{message}"
  end

  def oper(username, password)
    send "OPER #{username} #{password}"
  end

  def part(channels, message=nil)
    channels = channels.join(',') if channels.is_a?(Array)
    send "PART #{channels} #{message}"
  end

  def pass(password)
      send "PASS #{password}"
  end

  def ping(server1, server2=nil)
    send "PING #{server1} #{server2}"
  end

  def pong(server1, server2=nil)
    send "PONG #{server1} #{server2}"
  end

  def privmsg(msgtarget, message)
    send "PRIVMSG #{msgtarget} #{message}"
  end

  alias :say_to :privmsg

  def quit(message=nil)
    send "QUIT #{message}"
  end

  def rehash
    send "REHASH"
  end

  def restart
    send "RESTART"
  end

  def rules
    send "RULES"
  end

  def server(servername, hopcount, info)
    send "SERVER #{servername} #{hopcount} #{info}"
  end

  def service(nickname, reserved1, distribution, type, reserved2, info)
    send "SERVICE #{nickname} #{reserved1} #{distribution} #{type} #{reserved2} #{info}"
  end

  def servlist
    send "SERVLIST"
  end

  def servlist(mask, type=nil)
    send "SERVLIST #{mask} #{type}"
  end

  def squery(servicename, text)
    send "SQUERY #{servicename} #{text}"
  end

  def squit(server, comment)
    send "SQUIT #{server} #{comment}"
  end

  def setname(real_name)
    # Not formally defined in RFC
    send "SETNAME #{real_name}"
  end

  def silence(hostmask)
    # Not formally defined in RFC
    send "SILENCE #{hostmask}"
  end

  def stats(query, server=nil)
    send "STATS #{query} #{server}"
  end

  def summon(user)
    send "SUMMON #{user}"
  end

  def summon(user, server, channel=nil)
    send "SUMMON #{user} #{server} #{channel}"
  end

  def time(server=nil)
    send "TIME #{server}"
  end

  def topic(channel, topic=nil)
    send "TOPIC #{channel} #{topic}"
  end

  def trace(target=nil)
    send "TRACE #{target}"
  end

  def uhnames
    send "PROTOCTL UHNAMES"
  end

  def user(user, mode, realname)
    send "USER #{user} #{mode} * #{realname}"
  end

  def userhost(nickname)
    nickname = nickname.join(' ') if nickname.is_a?(Array)
    send "USERHOST #{nickname}"
  end

  def userip(nickname)
    # Not formally in RFC
    send "USERIP #{nickname}"
  end

  def users(server=nil)
    send "USERS #{server}"
  end

  def version(server=nil)
    send "VERSION #{server}"
  end

  def wallops(message)
    send "WALLOPS #{message}"
  end

  def watch(nicknames)
    # Not formally in RFC
    nicknames = nicknames.join(' ') if nicknames.is_a?(Array)
    send "WATCH #{nicknames}"
  end

  def who
    send "WHO"
  end

  def who(name, operators=false)
    send "WHO #{name} #{operators ? 'o' : ''}"
  end

  def whois(nicknames, server=nil)
    nicknames = nicknames.join(',') if nicknames.is_a?(Array)
    send "WHOIS #{server} #{nicknames}"
  end

  def whowas(nickname)
    nicknames = nicknames.join(',') if nicknames.is_a?(Array)
    send "WHOWAS #{nickname}"
  end

  def whowas(nickname, count, server=nil)
    nicknames = nicknames.join(',') if nicknames.is_a?(Array)
    send "WHOWAS #{nickname} #{count} #{server}"
  end

  # Non-RFC
  def back
    away ''
  end
end