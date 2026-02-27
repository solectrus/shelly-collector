module BatchFormatting
  def format_values(record, widths)
    time = Time.at(record.time).localtime.strftime('%H:%M:%S')
    power = record.power.round(1).to_s.rjust(widths[:power])
    line = "#{time}, Power #{power} W"
    line += ", Temperature #{record.temp.to_s.rjust(widths[:temp])} °C" if record.temp
    line
  end

  def max_field_length(records)
    records.filter_map { |r| yield(r)&.length }.max
  end
end
