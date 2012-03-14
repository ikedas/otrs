# --
# Kernel/System/User/Preferences/DB.pm - some user functions
# Copyright (C) 2001-2012 OTRS AG, http://otrs.org/
# --
# $Id: DB.pm,v 1.20 2012-03-14 12:29:47 mh Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::User::Preferences::DB;

use strict;
use warnings;

use vars qw(@ISA $VERSION);
$VERSION = qw($Revision: 1.20 $) [1];

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for (qw(DBObject ConfigObject LogObject CacheInternalObject)) {
        $Self->{$_} = $Param{$_} || die "Got no $_!";
    }

    # preferences table data
    $Self->{PreferencesTable} = $Self->{ConfigObject}->Get('PreferencesTable')
        || 'user_preferences';
    $Self->{PreferencesTableKey} = $Self->{ConfigObject}->Get('PreferencesTableKey')
        || 'preferences_key';
    $Self->{PreferencesTableValue} = $Self->{ConfigObject}->Get('PreferencesTableValue')
        || 'preferences_value';
    $Self->{PreferencesTableUserID} = $Self->{ConfigObject}->Get('PreferencesTableUserID')
        || 'user_id';

    # create cache prefix
    $Self->{CachePrefix} = 'UserPreferencesDB'
        . $Self->{PreferencesTable}
        . $Self->{PreferencesTableKey}
        . $Self->{PreferencesTableValue}
        . $Self->{PreferencesTableUserID};

    return $Self;
}

sub SetPreferences {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(UserID Key)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # delete old data
    return if !$Self->{DBObject}->Do(
        SQL => "DELETE FROM $Self->{PreferencesTable} WHERE "
            . " $Self->{PreferencesTableUserID} = ? AND $Self->{PreferencesTableKey} = ?",
        Bind => [ \$Param{UserID}, \$Param{Key} ],
    );

    # insert new data
    return if !$Self->{DBObject}->Do(
        SQL => "INSERT INTO $Self->{PreferencesTable} ($Self->{PreferencesTableUserID}, "
            . " $Self->{PreferencesTableKey}, $Self->{PreferencesTableValue}) "
            . " VALUES (?, ?, ?)",
        Bind => [ \$Param{UserID}, \$Param{Key}, \$Param{Value} ],
    );

    # delete cache
    $Self->{CacheInternalObject}->Delete(
        Key => $Self->{CachePrefix} . 'Preference' . $Param{UserID},
    );

    return 1;
}

sub GetPreferences {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(UserID)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # read cache
    my $CacheKey = $Self->{CachePrefix} . 'Preference' . $Param{UserID};
    my $Cache = $Self->{CacheInternalObject}->Get( Key => $CacheKey );
    return %{$Cache} if $Cache;

    # get preferences
    return if !$Self->{DBObject}->Prepare(
        SQL => "SELECT $Self->{PreferencesTableKey}, $Self->{PreferencesTableValue} "
            . " FROM $Self->{PreferencesTable} WHERE $Self->{PreferencesTableUserID} = ?",
        Bind => [ \$Param{UserID} ],
    );

    my %Data;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $Data{ $Row[0] } = $Row[1];
    }

    # set cache
    $Self->{CacheInternalObject}->Set(
        Key   => $Self->{CachePrefix} . 'Preference' . $Param{UserID},
        Value => \%Data,
    );

    return %Data;
}

sub SearchPreferences {
    my ( $Self, %Param ) = @_;

    my $Key   = $Param{Key}   || '';
    my $Value = $Param{Value} || '';

    # get preferences
    my $SQL = "SELECT $Self->{PreferencesTableUserID}, $Self->{PreferencesTableValue} "
        . " FROM "
        . " $Self->{PreferencesTable} "
        . " WHERE "
        . " $Self->{PreferencesTableKey} = '"
        . $Self->{DBObject}->Quote($Key) . "'" . " AND "
        . " LOWER($Self->{PreferencesTableValue}) LIKE LOWER('"
        . $Self->{DBObject}->Quote( $Value, 'Like' ) . "')";

    return if !$Self->{DBObject}->Prepare( SQL => $SQL );

    my %UserID;
    while ( my @Row = $Self->{DBObject}->FetchrowArray() ) {
        $UserID{ $Row[0] } = $Row[1];
    }

    return %UserID;
}

1;
