# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
require_relative '../../between-meals/changes/change'
require_relative '../../between-meals/changes/databag'
require 'logger'

describe BetweenMeals::Changes::Databag do
  let(:logger) do
    Logger.new('/dev/null')
  end
  let(:roles_dir) do
    'databags'
  end

  FIXTURES = [
    {
      :name => 'empty filelists',
      :files => [],
      :result => [],
    },
    {
      :name => 'delete databag',
      :files => [
        {
          :status => :deleted,
          :path => 'databags/test/databag1.json'
        },
        {
          :status => :deleted,
          :path => 'databags/test1/test2/databag2.json'
        },
        {
          :status => :modified,
          :path => 'cookbooks/two/cb_one/metadata.rb'
        },
      ],
      :result => [
        ['test', :deleted],
      ],
    },
    {
      :name => 'add/modify a databag',
      :files => [
        {
          :status => :modified,
          :path => 'databags/one/databag1.json'
        },
        {
          :status => :deleted,
          :path => 'databags/test/databag2.rb' # wrong extension
        },
        {
          :status => :deleted,
          :path => 'databags/two/databag3.json'
        },
      ],
      :result => [
        ['one', :modified], ['two', :deleted]
      ],
    },
  ]

  FIXTURES.each do |fixture|
    it "should handle #{fixture[:name]}" do
      BetweenMeals::Changes::Databag.find(
        fixture[:files],
        roles_dir,
        logger
      ).map do |cb|
        [cb.name, cb.status]
      end.
      should eq(fixture[:result])
    end
  end

end
