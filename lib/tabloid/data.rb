module Tabloid
  class Data
    attr_accessor :report_columns
    attr_reader :rows

    def initialize(options = {})
      raise ArgumentError.new("Must supply row data") unless options[:rows]
      raise ArgumentError.new("Must supply column data") unless options[:report_columns]

      @report_columns   = options[:report_columns]
      @grouping_key     = options[:grouping_key]
      @grouping_options = options[:grouping_options] || {:total => true}
      @summary_options  = options[:summary] || {}

      @rows = convert_rows(options[:rows])

    end

    def to_csv
      header_csv + rows.map(&:to_csv).join + summary_csv
    end

    def to_html
      header_html + rows.map(&:to_html).join + summary_html
    end

    private
    def convert_rows(rows)
      rows.map! do |row|
        Tabloid::Row.new(:columns => @report_columns, :data => row)
      end

      if @grouping_key
        rows = rows.group_by { |r| r[@grouping_key] }
      else
        rows = {:default => rows}
      end

      rows.keys.sort.map do |key|
        data_rows = rows[key]

        label = (key == :default ? false : key)
        Tabloid::Group.new :columns => @report_columns, :rows => data_rows, :label => label, :total => @grouping_options[:total]
      end
    end

    def header_csv
      FasterCSV.generate do |csv|
        csv << @report_columns.map(&:to_header)
      end
    end

    def header_html
      headers = Builder::XmlMarkup.new
      headers.tr do |tr|
        @report_columns.each do |col|
          tr.th(col.to_header, "class" => col.key) unless col.hidden?
        end
      end
    end

    def summary_html
      summary_rows.map { |row| row.to_html(:class => "summary") }.join
    end

    def summary_csv
      summary_rows.map(&:to_csv).join
    end

    #perform the supplied block on all rows in the data structure
    def summarize(key, block)
      summaries = rows.map { |r| r.summarize(key, &block) }
      if summaries.any?
        summaries[1..-1].inject(summaries[0]) do |summary, val|
          block.call(summary, val)
        end
      else
        nil
      end
    end

    def summary_rows
      data_summary = report_columns.map do |col|
        if summarizer = @summary_options[col.key]
          summarize(col.key, self.send(summarizer)) unless col.hidden?
        end

      end
      [
          Tabloid::HeaderRow.new("Totals", :column_count => visible_column_count),
          Tabloid::Row.new(:columns => @report_columns,
                           :data    => data_summary)

      ]

    end

    def visible_column_count
      @visible_col_count ||= @report_columns.count { |col| !col.hidden? }
    end

    def sum
      proc(&:+)
    end
  end
end