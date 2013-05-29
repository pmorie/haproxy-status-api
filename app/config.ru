require 'socket'
require 'pp'
require 'json'

class HAProxyAttr
    attr_accessor :pxname,:svname,:qcur,:qmax,:scur,:smax,:slim,:stot,:bin,:bout,:dreq,:dresp,:ereq,:econ,:eresp,:wretr,:wredis,:status,:weight,:act,:bck,:chkfail,:chkremove,:lastchg,:removetime,:qlimit,:pid,:iid,:sid,:throttle,:lbtot,:tracked,:type,:rate,:rate_lim,:rate_max,:check_status,:check_code,:check_duration,:hrsp_1xx,:hrsp_2xx,:hrsp_3xx,:hrsp_4xx,:hrsp_5xx,:hrsp_other,:hanafail,:req_rate,:req_rate_max,:req_tot,:cli_abrt,:srv_abrt

    def initialize(line)
        (@pxname,@svname,@qcur,@qmax,@scur,@smax,@slim,@stot,@bin,@bout,@dreq,@dresp,@ereq,@econ,@eresp,@wretr,@wredis,@status,@weight,@act,@bck,@chkfail,@chkremove,@lastchg,@removetime,@qlimit,@pid,@iid,@sid,@throttle,@lbtot,@tracked,@type,@rate,@rate_lim,@rate_max,@check_status,@check_code,@check_duration,@hrsp_1xx,@hrsp_2xx,@hrsp_3xx,@hrsp_4xx,@hrsp_5xx,@hrsp_other,@hanafail,@req_rate,@req_rate_max,@req_tot,@cli_abrt,@srv_abrt) = line.split(',')
    end
end


map '/' do
  status = proc do |env|
    req = Rack::Request.new(env)
    addtl_gears_count = req.params['addtlGearsCount']
    addtl_gears_load = req.params['addtlGearsLoad']
    addtl_gears_count = addtl_gears_count.to_i if addtl_gears_count
    addtl_gears_load = addtl_gears_load.to_f if addtl_gears_load
    stats_sock="#{ENV['OPENSHIFT_HOMEDIR']}haproxy/run/stats"

    stats = {}
    error = nil
    session_capacity_pct = nil
    output = {}

    begin
      socket = UNIXSocket.open(stats_sock)
      socket.puts("show stat\n") 
      while(line = socket.gets) do
        pxname=line.split(',')[0]
        svname=line.split(',')[1]
        stats[pxname] = {} unless stats[pxname]
        stats[pxname][svname] = HAProxyAttr.new(line)
      end
      socket.close

      gear_count = stats['express'].count - 3

      if gear_count == 0
        raise "Failed to get information from haproxy"
      end
      
      node_num = 1

      stats['express'].each do |name, attrs|
        if name != 'FRONTEND' && name != 'BACKEND' && name != 'filler'
          output[name] = { 'load_pct' => (attrs.scur.to_i / 40.0 ) * 100, 'node' => "node#{node_num}", 'current_sessions' => attrs.scur.to_i }
          node_num += 1
        end
      end
      
      if addtl_gears_count
        i = 2
        addtl_gears_count.times do
          output["gear#{i.to_s}"] = { 'load_pct' => addtl_gears_load, 'node' => "node#{node_num}", 'current_sessions' => addtl_gears_load.to_i }
          i += 1
          node_num += 1
        end
      end
    rescue Exception => e
      error = "An error occurred: #{e.message}"
    end
    if error
      [500, { "Content-Type" => "text/html" }, [error]]
    else
      [200, { "Content-Type" => "application/javascript" }, ["haproxyStatus(#{output.to_json})"]]
    end
  end
  run status
end