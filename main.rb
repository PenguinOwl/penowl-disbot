require 'discordrb'
require 'open-uri'
require 'pg'
require 'date'

$error = 0
$pres = <<'here'
  ___  ___  ___  ___  _____  ___  ___  ___ 
 | _ \| _ \| __|/ __||_   _||_ _|/ __|| __|
 |  _/|   /| _| \__ \  | |   | || (_ || _| 
 |_|  |_|_\|___||___/  |_|  |___|\___||___|
here
class Discordrb::Events::MessageEvent
  attr_accessor :conn
end
class String
  def pad(align="center")
    fin = ""
    lg = 0
    d = self.dup.split("\n")
    d.each do |str|
      length = str.center(str.length+2).length
      lg = length if lg < length
    end
    fin << "+" + ("-" * lg) + "+\n"
    d.each do |str|
      if str == "$$"
        fin << "+" + ("-" * lg) + "+\n"
      else
        dec = align
        if str[0..1] == "~<"
          dec = "ljust"
          str[0..1] == ""
        elsif str[0..1] == "~>"
          dec = "rjust"
          str[0..1] == ""
        elsif str[0..1] == "~^"
          dec = "center"
          str[0..1] = ""
        end
        fin << "|" + str.send(dec, lg) + "|\n"
      end
    end
    fin << "+" + ("-" * lg) + "+\n"
    return fin
  end
  def mon(pos=false)
    d = self.dup
    d = d.to_f * 0.01
    if d < 0 && pos
      d = d * -1
    end
    t = -1
    pr = ""
    t, pr = case d
      when (10**6)..((10**9)-1); [1, "M"]
      when (10**9)..((10**12)-1); [2, "B"]
      when (10**12)..((10**15)-1); [3, "T"]
      when (10**15)..((10**18)-1); [4, "Qu"]
      when (10**18)..((10**21)-1); [5, "Qi"]
      when d < (10^21); [6, "S"]
    else
      [-1, ""]
    end
    t = 3 * t
    t = t + 3
    t = 10**(t)
    d = d / t
    r = sprintf "%.2f", d
    r = r.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    r << pr
    return r
  end
end
def stack(i)
  max = Math.sqrt(i)
  max = max.to_i
  amt = ((max+1)**2)-(max**2)
  camt = i-(max**2)
  prog = camt.to_f/amt.to_f
  return [max,prog,camt,amt]
end
def pres(event, mem)
  begin
    return Math.log10(((mget(event, mem, :bal).to_i)-(mget(event, mem,:tax).to_i)).to_f).to_i - 7
  rescue Math::DomainError
    return 0
  end
end
def todays(time=Time.now)
  time.strftime("%Y=%m=%H")
end
def taxdays(mydate)
    mydate.month != (mydate+10).month 
end
def link(event)
  conn = PG::Connection.open(ENV['DATABASE_URL'])
  event.conn = conn
  yield
  ensure
    event.conn.finish if event.conn
end
def pget(event, mem, type)
  a = true
  type = type.to_s
  event.conn.exec_params("select * from prestige where discrim=$1", [mem.id.to_s]) do |result|
    result.each do |row|
      return row.values_at(type).first
      a = false
    end
  end
  if a
    event.conn.exec_params("insert into prestige (discrim, lvl, steal, bonus, auto) values ($1, 0, 0, 0, 0)", [mem.id.to_s])
    event.conn.exec_params("select * from prestige where discrim=$1", [mem.id.to_s]) do |result|
      result.each do |row|
        return row.values_at(type).first
        a = false
      end
    end
  end
end
def pset(event, mem, type, val)
  type = type.to_s
  mget(event, mem, :lvl)
  event.conn.exec_params("update prestige set #{type}=$1 where discrim=$2", [val, mem.id.to_s])
end
def mget(event, mem, type)
  a = true
  type = type.to_s
  event.conn.exec_params("select * from users where userid=$1 and serverid=$2", [mem.id.to_s, mem.server.id]) do |result|
    result.each do |row|
      return row.values_at(type).first
      a = false
    end
  end
  if a
    event.conn.exec_params("insert into users (userid, serverid, tax, bal, credit, taxamt, daily, invest, invcost, lbcount, state, pres, stack) values ($1, $2, 0, 700, 0, 5, 150, 0, 500, 0, 0, 0, 0)", [mem.id.to_s, mem.server.id])
    event.conn.exec_params("select * from users where userid=$1 and serverid=$2", [mem.id.to_s, mem.server.id]) do |result|
      result.each do |row|
        return row.values_at(type).first
        a = false
      end
    end
  end
end
def mset(event, mem, type, val)
  type = type.to_s
  mget(event, mem, :tax)
  event.conn.exec_params("update users set #{type}=$1 where userid=$2 and serverid=$3", [val, mem.id.to_s, mem.server.id])
end
$prefix= '='
puts "key", ENV['KEY']
$bot = Discordrb::Bot.new token: ENV['KEY'], client_id: ENV['CLIENT']
puts $bot.invite_url
puts ARGV[0]
def command(command,event,args)
  if ENV['DEBUG'] == 'true'
    unless mget(event, event.author, :state) == "1" and not command == "unfreeze"
      Command.send(command,event,*args)
    else
      event.respond "**Your account is frozen! Unfreeze it with** `#{$prefix}unfreeze`"
    end
  else
    begin
      begin
        unless mget(event, event.author, :state) == "1" and not command == "unfreeze"
          Command.send(command,event,*args)
        else
          event.respond "**Your account is frozen! Unfreeze it with** `#{$prefix}unfreeze`"
        end
      rescue ArgumentError
        mem = event.author
        if mget(event, mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)  && mget(event, mem, :state) == "0"
          mset(event, event.author, :tax, mget(event, event.author, :tax).to_i+mget(event, event.author, :taxamt).to_i)
        end
        event.respond("Argument error!")
      end
    rescue NoMethodError
      mem = event.author
      if mget(event, mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
        mset(event, event.author, :tax, mget(event, event.author, :tax).to_i+mget(event, event.author, :taxamt).to_i)
      end
      event.respond("That's not a command!")
    end
  end
end

$bot.message() do |event|
  link(event) do
    mem = event.author.on(event.channel.server)
    if mget(event, mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
      mset(event, mem, :tax, mget(event, mem, :tax).to_i+mget(event, mem, :taxamt).to_i)
    end
    if event.message.content.strip[0] == $prefix or (event.message.mentions.map {|item| item.id}).include? $bot.profile.id
      if (event.message.mentions.map {|item| item.id}).include? $bot.profile.id
        cmd = event.message.content.strip
        unless cmd[1] == ">"
          cmd.downcase!
        end
        cmd = cmd.split(" ")
        cmd.delete_at(0)
        top = cmd[0]
        cmd.map! {|e| e.gsub("_"," ")}
        cmd.delete_at(0)
        command(top, event, cmd)
        mem = event.author
      else
        cmd = event.message.content.strip
        unless cmd[1] == ">"
          cmd.downcase!
        end
        cmd[0] = ""
        cmd = cmd.split(" ")
        top = cmd[0]
        cmd.map! {|e| e.gsub("_"," ")}
        cmd.delete_at(0)
        command(top, event, cmd)
        mem = event.author
      end
    end
  end
end

def tax(dfs, event)
  link(event) do
    mem = dfs.on(event.channel.server)
    if mget(event, mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
      mset(event, mem, :tax, mget(event, event.author, :tax).to_i+mget(event, mem, :taxamt).to_i)
    end
  end
end

def af(em, cmd, ds)
  em.add_field(name: $prefix+cmd, value: ds)
end

class Command

  #-----------------------------
  #          COMMANDS
  #-----------------------------

  def Command.rubber(event)
    event.respond("woot")
  end
  
  def Command.version(event)
    event.respond(ENV['HEROKU_RELEASE_VERSION'])
  end

  def Command.ispaulgreat(event)
    event.respond("yea " + event.author.mention)
  end

  def Command.setplaying(event, text)
    if event.author.id=="PenguinOwl#3931"
      $bot.game= text
    else
      event.respond "but ur not penguin"
    end
  end

  def Command.taxes(event, *args)
    mem = event.author
    if event.message.mentions.size == 0
      if mget(event, mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
        event.respond("You owe $#{mget(event, mem, :tax).mon} to the IRS. You have $#{mget(event, mem, :bal).mon}.")
      else
        event.respond("You have paid your taxes.")
      end
    end
    event.message.mentions.each do |mem|
      if mget(event, mem.on(event.channel.server), :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
        mem = mem.on(event.channel.server)
        event.respond(mem.mention + " owes $#{mget(event, mem, :tax).mon} to the IRS. They have $#{mget(event, mem, :bal).mon}.")
      else
        event.respond(mem.mention + " has paid their taxes.")
      end
    end
  end
  
  def Command.freeze(event, arg="elolo")
    if arg == "confirm"
      mem = event.author
      mset(event, mem, :state, 1)
      event.respond("**Your account has been frozen.**")
    else
      event.respond("**" + event.author.mention + ", are you sure that you want to freeze your account? This action will reset your balance. If you are sure you want to proceed, do** `#{$prefix}freeze confirm`")
    end
  end
  
  def Command.prestige(event, arg="elolo")
    mem = event.author
    if pres(event, mem) > 0
      if arg == "confirm"
        mem = event.author
        pset(event, mem, :lvl, pget(event, mem, :lvl).to_i + pres(event, mem))
        pset(event, mem, :points, pget(event, mem, :points).to_i + pres(event, mem))
        event.conn.exec_params("delete from users where userid=$1 and serverid=$2", [mem.id.to_s, mem.server.id])
        event.respond("@here " + mem.mention + " has decided to ```" + ($pres + "\n~^" + mem.distinct).pad("ljust") + "```")
      else
        event.respond("**" + event.author.mention + ", are you sure that you want to prestige? This action will reset your entire account (except your prestige level and upgrades) and will add #{pres(event, mem).to_s} prestige levels to it. If you are sure you want to proceed, do** `#{$prefix}prestige confirm`")
      end
    else
      event.respond "You need at least 1M to prestige! (After taxes)"
    end
  end
  
  def Command.migrate(event)
    dec = false
    mem = event.author
    mget(event, mem, :tax)
    event.conn.exec_params("select userid from users where userid=$1 and serverid=$2", [mem.distinct.to_s, mem.server.id]).each do |res|
      dec = true if res["userid"].include? "#"
    end
    if dec
      event.conn.exec_params("delete from users where userid=$1", [mem.id.to_s])
      event.conn.exec_params("update users set userid=$2 where userid=$1", [mem.distinct, mem.id.to_s])
    end
    dec = false
    mem = event.author
    pget(event, mem, :tax)
    event.conn.exec_params("select discrim from prestige where discrim=$1", [mem.distinct.to_s]).each do |res|
      dec = true if res["discrim"].include? "#"
    end
    if dec
      event.conn.exec_params("delete from prestige where discrim=$1", [mem.id.to_s])
      event.conn.exec_params("update prestige set discrim=$2 where discrim=$1", [mem.distinct, mem.id.to_s])
    end
  end
  
#  def Command.upgrade(event, type="info")
#    if ["bonus", "steal", "auto"].include? type
#      mem = event.author.on(event.channel.server)
#      if pget(event, mem, :points).to_i>=(pget(event, mem, type.to_sym).to_i+1)
#        pset(event, mem, :points, pget(event, mem, :points).to_i - (pget(event, mem, type.to_sym).to_i+1))
#        pset(event, mem, type.to_sym, (pget(event, mem, type.to_sym).to_i+1))
#        event.respond "**Upgraded your** `#{type}` **skill to level #{pget(event, mem, type.to_sym)}.**"
#      else
#        event.respond "Not enough prestige points!"
#      end
#    else
#      event.respond "You can only upgrade bonus, steal, and auto."
#    end
#  end
  
  def Command.unfreeze(event)
    mem = event.author
    mset(event, mem, :bal, 0)
    mset(event, mem, :state, 0)
    event.respond("**Your account has been unfrozen and your balance has been reset.**")
  end
  
  def Command.money(event, *args)
    mem = event.author
    if event.message.mentions.size == 0
      if args.size != 0
        tax mem, event
      end
      event.respond("**You have $#{mget(event, mem, :bal).mon}.**")
    end
    event.message.mentions.each do |mem|
      mem = mem.on(event.channel.server)
      event.respond("**" + mem.mention + " has $#{mget(event, mem, :bal).mon}.**")
    end
  end
  
  def Command.top(event, type="daily")
    if ["bal","daily","invest","lbcount"].include? type
      out = "~^Leaderboard of #{event.channel.server.name}"
      out << "\n~^By " + case type
        when "bal"; "Balance"
        when "daily"; "Hourly Rewards"
        when "invest"; "Investments"
        when "lbcount"; "Lobbys"
      end + "\n$$"
      serverid = event.channel.server.id
      event.conn.exec_params("select distinct userid, #{type} from users where serverid=$1 and state!=1 and userid similar to '[0123456789]+' order by #{type} desc limit 10", [event.channel.server.id]) do |result|
        a = 1
        result.each do |row|
          r = row
          out << "\n #{a.to_s}. #{event.channel.server.member(r["userid"].to_i).name} - #{ if ["invest","lbcount"].include? type then "#{r[type].to_s}" else "$#{r[type].mon.to_s}" end}"
          a = a + 1
        end
      end
      event.respond("```" + out.pad("ljust") + "```")
    elsif type == "pres"
      out = "~^Prestige Leaderboard\n$$"
      serverid = event.channel.server.id
      result = event.conn.exec("select discrim, lvl from prestige where discrim similar to '[0123456789]+' order by lvl desc limit 10")
      a = 1
      result.each do |row|
        r = row
        out << "\n #{a.to_s}. #{if r["discrim"] =~ /^[0-9]+$/ and event.channel.server.member(r["discrim"].to_i) then event.channel.server.member(r["discrim"].to_i).name else "Unknown" end} - #{r["lvl"].to_s}"
        a = a + 1
      end
      event.respond("```" + out.pad("ljust") + "```")
    else
      event.respond "Not a vaild ladder!"
    end
  end
  
  def Command.id(event, *args)
    mem = event.author
    if event.message.mentions.size == 0
      if args.size != 0
        tax mem, event
      end
      event.respond("**You are id $#{mget(event, mem, :id)}.**")
    end
    event.message.mentions.each do |mem|
      mem = mem.on(event.channel.server)
      event.respond("**" + mem.mention + " is id $#{mget(event, mem, :id)}.**")
    end
  end
  
  def Command.richest(event)
    money(event, "bal")
  end
    
  def Command.balance(event, *args)
    money(event, *args)
  end
  
  def Command.stats(event, *args)
    info(event, *args, "noborder")
  end
  
  def Command.bal(event, *args)
    money(event, *args)
  end
  
  def Command.collect(event, *args)
    reward(event, *args)
  end
  
  def Command.info(event, *args)
    mem = event.author
    conc = ""
    if event.message.mentions.size == 0
      if args.size != 0
        tax mem, event
      end
      s = ""
      if mget(event, mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
         s = "$" + mget(event, mem, :tax).mon
      else
         s = "Paid"
      end
      mem = event.author
      n = ""
      if mem.nick
        n = mem.nick
      else
        n = mem.username
      end
      conc = <<endofstring
#{n}'s Stats
$$
Tax: #{s}
Balance: $#{mget(event, mem, :bal).mon}
Hourly Reward: $#{mget(event, mem, :daily).mon}
Tax Rate: $#{mget(event, mem, :taxamt).mon} per message
Investments: #{mget(event, mem, :invest).to_s}
Investment Cost: $#{mget(event, mem, :invcost).mon}
Times Lobbied: #{mget(event, mem, :lbcount)}
endofstring
      pb = pget(event, mem, :lvl).to_i
      if pb > 0
        st = stack(pb)
        conc << <<endofstring
$$
Prestige
$$
Level: #{pget(event, mem, :lvl)}
Current Stack: #{2**(mget(event, mem, :stack).to_i)}x
Max Stack: #{2**(st[0]+1)}x
Progress
#{"█"*(st[1]*20).to_i}#{"▒"*(10-(st[1]*20).to_i)}
#{st[2]}/#{st[3]}
endofstring
      end
    end
    event.message.mentions.each do |mem|
      s = ""
      if mget(event, mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
         s = "$" + mget(event, mem, :tax).mon
      else
         s = "Paid"
      end
      mem = event.author
      n = ""
      if mem.nick
        n = mem.nick
      else
        n = mem.username
      end
      conc = <<endofstring
#{n}'s Stats
$$
Tax: #{s}
Balance: $#{mget(event, mem, :bal).mon}
Hourly Reward: $#{mget(event, mem, :daily).mon}
Tax Rate: $#{mget(event, mem, :taxamt).mon} per message
Investments: #{mget(event, mem, :invest).to_s}
Investment Cost: $#{mget(event, mem, :invcost).mon}
Times Lobbied: #{mget(event, mem, :lbcount)}
endofstring
      pb = pget(event, mem, :lvl).to_i
      if pb > 0
        st = stack(pb)
        conc << <<endofstring
$$
Prestige
$$
Level: #{pget(event, mem, :lvl)}
Current Stack: #{2**(mget(event, mem, :stack).to_i)}x
Max Stack: #{2**(st[0]+1)}x
Progress
#{"█"*(st[1]*20).to_i}#{"▒"*(10-(st[1]*20).to_i)}
#{st[2]}/#{st[3]}
endofstring
      end
    end
    if args.include? "noborder"
      event.respond "```" + conc + "```"
    else
      event.respond "```" + conc.pad + "```"
    end
  end
  
  def Command.reward(event)
    mem = event.author
    unless mget(event, mem, :day) == todays
      mset(event, mem, :bal, mget(event, mem, :daily).to_i + mget(event, mem, :bal).to_i)
      event.respond "**Collected $#{mget(event, mem, :daily).mon} from the bank.**"
      pb = pget(event, mem, :lvl).to_i
      if pb > 0
        bst = stack(pb)
        curr = mget(event, mem, :stack).to_i
        event.respond "*#{curr**2}x from stack!#{" (MAXED)" if bst[0].to_i == curr}*"
        mset(event, mem, :bal, (mget(event, mem, :daily).to_f.*(curr**2)).to_i + mget(event, mem, :bal).to_i)
        if mget(event, mem, :day) == todays(Time.now-3600) 
          if bst[0].to_i < curr
            mset(event, mem, :stack, (mget(event, mem, :stack)).to_i + 1)
          end
        else
          mset(event, mem, :stack, 0)
        end
      end
      mset(event, mem, :day, todays)
    else
      event.respond "You already collected your reward!"
    end
  end
  
  def Command.lobby(event, type)
    mem = event.author
    unless mget(event, mem, :lbday) == Date.today.to_s
      if ["taxes", "investments", "rates"].include? type
        mset(event, mem, :lbday, Date.today.to_s)
        mset(event, mem, :lbcount, mget(event, mem, :lbcount).to_i + 1)
        chance = 4
        if Date.today.sunday? or Date.today.saturday?
          chance = 24
        end
        if rand(chance) == 1
          event.respond "***YOU WERE CAUGHT IN THE PROCESS OF LOBBYING. YOU WERE SUED BY THE STATE.***"
          mset(event, mem, :tax, mget(event, mem, :lbcount).to_i*mget(event, mem, :invcost).to_i/2 + mget(event, mem, :tax).to_i)
        else
          if type == "rates"
            event.respond "**You successfully lobbied the tax code!**"
            unless mget(event, mem, :taxamt).to_i < 4
              mset(event, mem, :taxamt, mget(event, mem, :taxamt).to_i*(60+rand(30))/100)
            end
          elsif type == "investments"
            event.respond "**You successfully lobbied the stock market!**"
            mset(event, mem, :invcost, mget(event, mem, :invcost).to_i - (mget(event, mem, :invcost).to_i / 3))
          elsif type == "taxes"
            event.respond "**You successfully lobbied your local tax collecter!**"
            mset(event, mem, :tax, mget(event, mem, :tax).to_i / 2) 
          end
        end
      else
        event.respond "You can only lobby three agencies: investments, taxes, and rates."
        tax mem,event
      end
    else
      event.respond "You have already lobbied today!"
    end
  end
  
  def Command.help(event)
    event.author.dm.send_embed do |em|
      em.title = "Commands"
      em.color = 313600
      af(em, "help", "not hard to guess")
      af(em, "taxes [users]", "displays tax information")
      af(em, "balance [users]", "displays balance - aliases: bal, money")
      af(em, "info [users]", "displays everything you need to know - alias: stats")
      af(em, "pay (user) (amount)", "give someone some of your money")
      af(em, "collect", "collect your hourly wages")
      af(em, "invest", "invest money (shown in #{$prefix}info) to increase your hourly payment")
      af(em, "lobby (investments|taxes|rates)", "lobby the government to decrease one of your debts")
      af(em, "top [bal|invest|lbcount)", "see the leaderboards")
      af(em, "freeze", "opt out of tax bot")
      af(em, "paytaxes", "p a y   y o u r   t a x e s")
      af(em, "prestige", "reset for cool perks")
      af(em, "upgrade", "upgrade a perk")
      em.footer = Discordrb::Webhooks::EmbedFooter.new(text: "the irs is always watching", icon_url: $bot.profile.avatar_url)
    end
    event.respond (event.author.mention + ", check your dms!")
  end
  
  def Command.pay(event, ment, amt)
    mem = event.author
    amt = amt.to_s.match(/[\d\.]+/)[0].to_f.*(100).to_i
    bal = mget(event, mem, :bal).to_i
    if mget(event, mem, :payc).to_i < (Time.now-120).to_i
      if mget(event, event.message.mentions[0].on(event.channel.server), :invcost).to_i*2 > amt
        if amt <= mget(event, mem, :bal).to_i
          if event.message.mentions.size == 1
            mem2 = event.message.mentions[0].on(event.channel.server)
            mset(event, mem, :bal, bal-amt)
            mset(event, mem2, :bal, mget(event, mem2, :bal).to_i + amt)
            event.respond "**Paid " + mem2.mention + " $#{amt.to_s.mon}.**"
            mset(event, mem, :payc, (Time.now).to_i)
          else
            event.respond "Mention someone to pay them!"
            tax mem,event
          end
        else
          event.respond "Not enough money!"
        end
      else
        event.respond "You are paying this user too much!"
      end
    else
      event.respond "You can only pay someone once every other minute!"
    end
  end
    
  def Command.invest(event)
    mem = event.author.on(event.channel.server)
    if mget(event, mem, :invcost).to_i <= mget(event, mem, :bal).to_i
      event.respond "*Invested $#{mget(event, mem, :invcost).mon} into the stock market.*"
      mset(event, mem, :bal, mget(event, mem, :bal).to_i - mget(event, mem, :invcost).to_i)
      diff = (rand(mget(event, mem, :invcost).to_i/5) - mget(event, mem, :invcost).to_i/20) * 2
      if diff > 0
        event.respond "**Success!** Your investments matured and you recived a $#{diff.to_s.mon} raise!"
      else
        event.respond "**Oh no!** Your investments failed and you took a $#{diff.to_s.mon(true)} cut."
      end
      mset(event, mem, :invcost, mget(event, mem, :invcost).to_i + (mget(event, mem, :invcost).to_i / 5) + diff)
      mset(event, mem, :daily, mget(event, mem, :daily).to_i + diff)
      mset(event, mem, :invest, mget(event, mem, :invest).to_i + 1)
      irs = rand(2)
      if irs == 1 and diff > 0 
        event.respond "*The IRS saw your investment and decided to raise your taxes.*"
        mset(event, mem, :taxamt, mget(event, mem, :taxamt).to_i + mget(event, mem, :invcost).to_i / 100)
      else
        irs = 0
      end
    else
      event.respond "Not enough money!"
    end
  end
  
  def Command.paytaxes(event)
    mem = event.author
    if mget(event, mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
      if mget(event, mem, :tax).to_i <= mget(event, mem, :bal).to_i
        if taxdays(Date.today)
          mset(event, mem, :bal, mget(event, mem, :bal).to_i - mget(event, mem, :tax).to_i)
          mset(event, mem, :tax, 0)
          mset(event, mem, :month, Date.today.year.to_s + "-" + Date.today.month.to_s)
          event.respond "Taxes paid for the month of " + Date.today.strftime("%B") + "."
        else
          event.respond "You may only pay your taxes on the last 10 days of the month!"
        end
      else
        event.respond "You do not have enough money to pay your taxes!"
      end
    else
      event.respond "You have already paid your taxes this month!"
    end
  end
            
  
  
  def Command.>(event, *args)
    if event.author.id==205036731592867840
      event.respond eval args.join(" ")
    else
      event.respond "boi stop tryn to hack me"
    end
  end

  #-----------------------------
  #       END OF COMMANDS
  #-----------------------------

end

$bot.ready do
  $bot.game= "do "+$prefix+"help | " + (ENV['HEROKU_RELEASE_VERSION'] if ENV['DEV'] != "false")
end

$bot.run
