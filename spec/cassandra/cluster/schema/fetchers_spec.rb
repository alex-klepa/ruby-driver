# encoding: utf-8

#--
# Copyright 2013-2015 DataStax, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#++

require 'spec_helper'

module Cassandra
  class Cluster
    class Schema
      module Fetchers
        [
         ['1.2.19', V1_2_x],
         ['2.0.16', V2_0_x],
         ['2.1.9',  V2_1_x]
        ].each do |(version, klass)|
          data = JSON.load(File.read(File.dirname(__FILE__) + '/fetchers/' + version + '-data.json'))

          describe(klass) do
            let(:connection) { double('cql protocol handler') }
            let(:schema_type_parser) { TypeParser.new }
            subject { klass.new(schema_type_parser) }

            describe('#fetch') do
              before do
                allow(connection).to receive(:send_request) do |r|
                  case r
                  when Protocol::QueryRequest
                    if data.include?(r.cql)
                      Ione::Future.resolved(Protocol::RowsResultResponse.new(data[r.cql], nil, nil, nil))
                    else
                      raise "unsupported cql: #{request.cql}"
                    end
                  else
                    raise "unexpected request: #{request.inspect}"
                  end
                end
              end

              it 'correctly reconstructs the entire schema' do
                parts = []
                keyspaces = subject.fetch(connection).value
                keyspaces.each do |keyspace|
                  parts << keyspace.to_cql
                  keyspace.each_table do |table|
                    parts << table.to_cql
                  end
                end
                cql = parts.join("\n\n")
                expect(File.read(File.dirname(__FILE__) + '/fetchers/' + version + '-schema.cql')).to eq(cql)
              end
            end
          end
        end
      end
    end
  end
end